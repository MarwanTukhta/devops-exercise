variable "name_prefix" {
  type        = string
  description = "Prefix for network resources."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name for subnet tagging."
}
