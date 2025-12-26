output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "EKS cluster CA data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster."
  value       = aws_iam_openid_connect_provider.this.arn
}
