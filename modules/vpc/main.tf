############################
# VPC
############################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

############################
# Internet Gateway
############################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

############################
# Public Subnets
############################

resource "aws_subnet" "public" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = var.public_subnet_cidrs[idx]
    idx  = idx
  } }

  vpc_id                  = aws_vpc.this.id
  cidr_block               = each.value.cidr
  availability_zone        = each.key
  map_public_ip_on_launch  = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

############################
# Private Application Subnets
############################

resource "aws_subnet" "private_app" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = var.private_app_subnet_cidrs[idx]
    idx  = idx
  } }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-app-${each.key}"
    Tier = "private-app"
  })
}

############################
# Private Database Subnets
############################

resource "aws_subnet" "private_db" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = var.private_db_subnet_cidrs[idx]
    idx  = idx
  } }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-db-${each.key}"
    Tier = "private-db"
  })
}

############################
# Elastic IPs + NAT Gateways (one per AZ)
############################

resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

############################
# Route Tables - Public
############################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

############################
# Route Tables - Private App (one per AZ, routed to that AZ's NAT GW)
############################

resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-app-rt-${each.key}"
  })
}

resource "aws_route" "private_app_nat_access" {
  for_each = aws_route_table.private_app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

############################
# Route Tables - Private DB (no Internet route; local only)
############################

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-db-rt"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}
