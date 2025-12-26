output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC id."
}

output "public_subnet_ids" {
  value       = module.network.public_subnet_ids
  description = "Public subnet ids."
}

output "private_subnet_ids" {
  value       = module.network.private_subnet_ids
  description = "Private subnet ids."
}

output "public_alb_dns_name" {
  value       = data.aws_lb.public_alb.dns_name
  description = "Public ALB DNS name."
}

output "public_alb_name" {
  value       = var.public_alb_name
  description = "Public ALB name."
}

output "alb_controller_role_arn" {
  value       = aws_iam_role.alb_controller.arn
  description = "IAM role ARN for the AWS Load Balancer Controller."
}

output "public_waf_arn" {
  value       = aws_wafv2_web_acl.public_alb.arn
  description = "WAF ACL ARN for the public ALB."
}

output "cockroachdb_instance_id" {
  value       = module.db.instance_id
  description = "CockroachDB EC2 instance id."
}

output "cockroachdb_nlb_dns_name" {
  value       = module.db.nlb_dns_name
  description = "CockroachDB internal NLB DNS name."
}
