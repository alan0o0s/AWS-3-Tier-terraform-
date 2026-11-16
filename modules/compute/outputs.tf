output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the Launch Template."
  value       = aws_launch_template.app.id
}

output "key_pair_name" {
  description = "Name of the generated AWS Key Pair."
  value       = aws_key_pair.this.key_name
}

output "private_key_path" {
  description = "Local filesystem path of the generated private key (gitignored)."
  value       = local_sensitive_file.private_key.filename
}
