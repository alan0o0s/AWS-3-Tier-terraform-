output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB, for Route53 alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group, consumed by the Auto Scaling Group."
  value       = aws_lb_target_group.app.arn
}
