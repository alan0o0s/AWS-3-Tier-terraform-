############################
# EC2 IAM Role (assumed by application instances)
############################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name_prefix        = "${var.name_prefix}-ec2-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-role"
  })
}

# AWS-managed policy that grants the minimum needed for SSM Session Manager,
# so instances can be administered without opening SSH to the world.
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Narrow, explicit CloudWatch permissions instead of a broad managed policy -
# only what's needed to push custom metrics/logs from the instance.
data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_agent" {
  name_prefix = "${var.name_prefix}-cw-agent-"
  role        = aws_iam_role.ec2.id
  policy      = data.aws_iam_policy_document.cloudwatch_agent.json
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.name_prefix}-ec2-"
  role        = aws_iam_role.ec2.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-instance-profile"
  })
}
