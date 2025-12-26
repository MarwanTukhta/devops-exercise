variable "name_prefix" {
  type        = string
  description = "Prefix for EKS resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC id."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids for worker nodes."
}
