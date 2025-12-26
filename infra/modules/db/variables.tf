variable "name_prefix" {
  type        = string
  description = "Prefix for DB resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC id."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids allowed to reach the DB."
}

variable "db_subnet_ids" {
  type        = list(string)
  description = "Private DB subnet ids for the DB instance and NLB."
}

variable "cockroach_instance_type" {
  type        = string
  description = "Instance type for CockroachDB."
  default     = "t3.medium"
}

variable "cockroach_key_name" {
  type        = string
  description = "Optional EC2 key pair name for CockroachDB."
  default     = null
}

variable "cockroach_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for CockroachDB."
  default     = 50
}
