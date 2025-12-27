output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Protected public subnet ids."
  value       = values(aws_subnet.public)[*].id
}

output "dmz_subnet_ids" {
  description = "DMZ firewall subnet ids."
  value       = values(aws_subnet.dmz)[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids."
  value       = values(aws_subnet.private)[*].id
}

output "private_db_subnet_ids" {
  description = "Private database subnet ids."
  value       = values(aws_subnet.private_db)[*].id
}

output "public_alb_security_group_id" {
  description = "Security group id for the public ALB in protected subnets."
  value       = aws_security_group.public_alb.id
}
