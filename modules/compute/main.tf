############################
# AMI discovery (Amazon Linux 2023, no hardcoded AMI IDs)
############################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################
# SSH Key Pair
# Generated locally via the TLS provider, registered with AWS, and the
# private key written to keys/ (gitignored). SSM is preferred for day-to-day
# administration; this key exists as a break-glass / optional-SSH fallback.
############################

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name_prefix = "${var.name_prefix}-key-"
  public_key      = tls_private_key.this.public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-key"
  })
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.root}/keys/${var.name_prefix}-key.pem"
  file_permission = "0400"
}

############################
# Launch Template
############################

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.this.key_name

  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # DB credentials reach the instance only via user_data -> a root-only env
  # file (see user-data.sh) - never logged, never in the app HTML output.
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    environment = var.environment
    db_host     = var.db_host
    db_port     = var.db_port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    db_engine   = var.db_engine
  }))

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # enforce IMDSv2
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-app-volume"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################
# Auto Scaling Group
############################

resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.name_prefix}-asg-"
  vpc_zone_identifier = var.private_app_subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  # ASG registers/deregisters instances with the Target Group automatically.
  target_group_arns = [var.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name_prefix}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################
# CPU-Based Target Tracking Scaling Policy
#
#   CPU > cpu_target (e.g. 50%)  -> scale out (add instances)
#   CPU comfortably below target -> scale in (remove instances)
#
# A target tracking policy manages both directions automatically: AWS
# continuously adjusts capacity to keep average CPU at the target value,
# which is the recommended approach over separate step-scaling alarms.
############################

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target
    disable_scale_in = false
  }

  # Stabilization: avoid flapping by giving the ASG time to settle between
  # scaling activities before re-evaluating.
  estimated_instance_warmup = 120
}

############################
# CloudWatch Alarms (for visibility into scaling behavior)
############################

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_target
  alarm_description   = "Average CPU across the ASG exceeded ${var.cpu_target}% - scale-out expected via target tracking policy"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.name_prefix}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_description   = "Average CPU across the ASG dropped below ${var.scale_in_cpu_threshold}% - scale-in expected via target tracking policy"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = var.tags
}
