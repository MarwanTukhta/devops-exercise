variable "name_prefix" {
  type        = string
  description = "Prefix for app resources."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS cluster endpoint."
}

variable "cluster_ca" {
  type        = string
  description = "EKS cluster CA data."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids for internal load balancers."
}

variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "vpc_id" {
  type        = string
  description = "VPC id."
}

variable "public_alb_name" {
  type        = string
  description = "Name for the public ALB created by the ALB controller."
}

variable "private_alb_name" {
  type        = string
  description = "Name for the private ALB created by the ALB controller."
}

variable "alb_controller_role_arn" {
  type        = string
  description = "IAM role ARN for the AWS Load Balancer Controller service account."
}

variable "retool_chart_version" {
  type        = string
  description = "Helm chart version for Retool."
  default     = "6.9.1"
}

variable "demo_api_image" {
  type        = string
  description = "Container image for the demo API."
  default     = "vad1mo/hello-world-rest:latest"
}

variable "demo_api_replicas" {
  type        = number
  description = "Number of demo API replicas."
  default     = 3
}

variable "retool_encryption_key" {
  type        = string
  description = "Encryption key for Retool configuration."
}

variable "retool_jwt_secret" {
  type        = string
  description = "JWT secret for Retool."
}

variable "retool_license_key" {
  type = string
  description = "License Key for retool"
}