variable "name_prefix" {
  type        = string
  description = "Prefix for observability resources."
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

variable "release_name" {
  type        = string
  description = "Helm release name for kube-prometheus-stack."
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  type        = string
  description = "Helm chart version for kube-prometheus-stack."
  default     = "80.6.0"
}

variable "grafana_ingress_host" {
  type        = string
  description = "Optional host for Grafana ingress."
  default     = ""
}
