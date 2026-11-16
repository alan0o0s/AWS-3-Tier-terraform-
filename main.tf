############################
# Availability Zone discovery
############################

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use explicitly provided AZs, otherwise auto-select az_count AZs from the region.
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    var.az_count
  )
}

############################
# Networking
############################

module "vpc" {
  source = "./modules/vpc"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = local.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  tags                     = local.common_tags
}

############################
# Security Groups
############################

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  db_port          = local.db_port
  enable_ssh       = var.enable_ssh
  ssh_allowed_cidr = var.ssh_allowed_cidr
  tags             = local.common_tags
}

############################
# IAM (EC2 instance role for SSM)
############################

module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

############################
# Application Load Balancer
############################

module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  tags              = local.common_tags
}

############################
# RDS Database
############################

module "rds" {
  source = "./modules/rds"

  name_prefix                = local.name_prefix
  private_db_subnet_ids      = module.vpc.private_db_subnet_ids
  db_sg_id                   = module.security_groups.db_sg_id
  db_engine                  = var.db_engine
  db_engine_version          = var.db_engine_version
  db_instance_class          = var.db_instance_class
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  storage_size               = var.storage_size
  max_storage_size           = var.max_storage_size
  backup_retention_period    = var.backup_retention_period
  multi_az                   = var.multi_az
  enable_deletion_protection = var.enable_deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  tags                       = local.common_tags
}

############################
# Compute (Launch Template + Auto Scaling Group)
############################

module "compute" {
  source = "./modules/compute"

  name_prefix             = local.name_prefix
  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_app_subnet_ids  = module.vpc.private_app_subnet_ids
  app_sg_id               = module.security_groups.app_sg_id
  instance_profile_name   = module.iam.instance_profile_name
  target_group_arn        = module.alb.target_group_arn
  instance_type           = var.instance_type
  min_size                = var.min_size
  desired_capacity        = var.desired_capacity
  max_size                = var.max_size
  cpu_target              = var.cpu_target
  scale_in_cpu_threshold  = var.scale_in_cpu_threshold
  root_volume_size        = var.root_volume_size
  tags                    = local.common_tags

  # The app tier connects directly to RDS - referencing these outputs also
  # gives Terraform the correct create order (RDS before the launch template
  # that bakes its endpoint into user_data).
  db_host     = module.rds.rds_address
  db_port     = module.rds.rds_port
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  db_engine   = var.db_engine
}
