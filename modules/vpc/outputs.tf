output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in AZ order."
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets, in AZ order."
  value       = [for az in var.availability_zones : aws_subnet.private_app[az].id]
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets, in AZ order."
  value       = [for az in var.availability_zones : aws_subnet.private_db[az].id]
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways, keyed by AZ."
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
}
