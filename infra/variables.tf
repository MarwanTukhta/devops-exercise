variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "malaa-exercise"
}

variable "aws_region" {
  type        = string
  description = "AWS region for the exercise."
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
  default     = "10.0.0.0/16"
}

variable "public_alb_name" {
  type        = string
  description = "Name for the public ALB created by the ALB controller."
  default     = "malaa-public-alb"
}

variable "private_alb_name" {
  type        = string
  description = "Name for the private ALB created by the ALB controller."
  default     = "malaa-private-alb"
}

variable "cockroach_ssh_password" {
  type        = string
  description = "Password for ec2-user SSH login to the DB instance."
  sensitive   = true
  default     = "dbpass123"
}

variable "retool_encryption_key" {
  type        = string
  description = "Encryption key for Retool configuration."
  sensitive = true
}

variable "retool_jwt_secret" {
  type        = string
  description = "JWT secret for Retool."
  sensitive = true
}

variable "retool_license_key" {
  type        = string
  description = "License key for Retool."
  sensitive = true
}
