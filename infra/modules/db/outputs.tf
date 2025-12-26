output "instance_id" {
  description = "CockroachDB EC2 instance id."
  value       = aws_instance.cockroachdb.id
}

output "nlb_dns_name" {
  description = "CockroachDB internal NLB DNS name."
  value       = aws_lb.cockroachdb.dns_name
}
