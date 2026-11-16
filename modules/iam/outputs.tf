output "role_arn" {
  description = "ARN of the EC2 IAM role."
  value       = aws_iam_role.ec2.arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile to attach to the launch template."
  value       = aws_iam_instance_profile.ec2.name
}
