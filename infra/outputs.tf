output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC id."
}

output "public_subnet_ids" {
  value       = module.network.public_subnet_ids
  description = "Protected public subnet ids."
}

output "dmz_subnet_ids" {
  value       = module.network.dmz_subnet_ids
  description = "DMZ firewall subnet ids."
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

output "public_alb_security_group_id" {
  value       = module.network.public_alb_security_group_id
  description = "Security group id for the public ALB in protected subnets."
}

output "cockroachdb_instance_id" {
  value       = module.db.instance_id
  description = "CockroachDB EC2 instance id."
}

output "cockroachdb_nlb_dns_name" {
  value       = module.db.nlb_dns_name
  description = "CockroachDB internal NLB DNS name."
}
