############################
# DB Subnet Group
############################

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name_prefix}-db-"
  subnet_ids  = var.private_db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

############################
# Engine defaults
############################

locals {
  engine = var.db_engine == "postgres" ? "postgres" : "mysql"
  port   = var.db_engine == "postgres" ? 5432 : 3306

  # aws_db_parameter_group family names vary by engine/version; pick a
  # reasonably current default family for each supported engine.
  parameter_group_family = var.db_engine == "postgres" ? "postgres18" : "mysql8.0"
}

############################
# Parameter Group
############################

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name_prefix}-pg-"
  family      = local.parameter_group_family
  description = "Parameter group for ${var.name_prefix} (${local.engine})"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-parameter-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

############################
# RDS Instance
############################

resource "aws_db_instance" "this" {
  identifier_prefix = "${var.name_prefix}-db-"

  engine         = local.engine
  engine_version = var.db_engine_version # null lets AWS pick the current default
  instance_class = var.db_instance_class

  allocated_storage     = var.storage_size
  max_allocated_storage = var.max_storage_size
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = local.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-db-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

############################
# CloudWatch Alarms
############################

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS average CPU utilization exceeded 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS database connection count is unusually high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }

  tags = var.tags
}
