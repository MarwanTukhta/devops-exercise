output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet ids."
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids."
  value       = values(aws_subnet.private)[*].id
}

output "private_db_subnet_ids" {
  description = "Private database subnet ids."
  value       = values(aws_subnet.private_db)[*].id
}