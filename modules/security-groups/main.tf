############################
# ALB Security Group
# Internet -> ALB on port 80 (and 443 if HTTPS is added later)
############################

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Allow inbound HTTP from the Internet to the ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from Internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################
# Application Security Group
# ALB -> EC2 on port 80 only. NOT open to the Internet directly.
############################

resource "aws_security_group" "app" {
  name_prefix = "${var.name_prefix}-app-"
  description = "Allow inbound HTTP only from the ALB security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# Optional, off by default - prefer SSM Session Manager for administration.
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "SSH from trusted CIDR (optional, prefer SSM)"
  cidr_ipv4         = var.ssh_allowed_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound (e.g. NAT for package installs, SSM endpoints)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################
# Database Security Group
# App -> RDS on the engine's port only. No Internet access at all.
############################

resource "aws_security_group" "db" {
  name_prefix = "${var.name_prefix}-db-"
  description = "Allow inbound database traffic only from the application security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "DB port from application tier only"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "db_all_out" {
  security_group_id = aws_security_group.db.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
