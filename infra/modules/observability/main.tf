data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = "monitoring"
  create_namespace = true
}

resource "helm_release" "vector" {
  name             = "vector"
  repository       = "https://helm.vector.dev"
  chart            = "vector"
  namespace        = "monitoring"
  create_namespace = true
}

resource "kubernetes_ingress_v1" "grafana" {
  count      = var.grafana_ingress_host == "" ? 1 : 0
  depends_on = [helm_release.kube_prometheus_stack]

  metadata {
    name      = "${var.release_name}-grafana"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internal"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "${var.release_name}-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
