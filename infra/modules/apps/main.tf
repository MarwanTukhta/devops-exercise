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

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.alb_controller_role_arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.alb_controller.metadata[0].name
    },
  ]
}

resource "helm_release" "retool" {
  name       = "retool"
  repository = "https://charts.retool.com"
  chart      = "retool"
  version    = var.retool_chart_version

  namespace  = "retool"
  create_namespace = true


  set = [
    {
      name = "image.tag"
      value = "latest"
    },
    {
      name = "config.encryptionKey"
      value = var.retool_encryption_key
    },
    {
      name = "config.licenseKey"
      value = var.retool_license_key
    },
    {
      name = "config.jwtSecret"
      value = var.retool_jwt_secret
    },
    {
      name = "ingress.enabled"
      value = "false"
    }
  ]
}

resource "kubernetes_ingress_v1" "retool_internal" {
  depends_on = [helm_release.aws_load_balancer_controller]
  metadata {
    name      = "retool-internal"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                 = "alb"
      "alb.ingress.kubernetes.io/load-balancer-name" = var.private_alb_name
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTP\":80}]"
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
              name = helm_release.retool.name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment_v1" "demo_api" {
  metadata {
    name      = "demo-api"
    namespace = "default"
    labels = {
      app = "demo-api"
    }
  }

  spec {
    replicas = var.demo_api_replicas

    selector {
      match_labels = {
        app = "demo-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "demo-api"
        }
      }

      spec {
        container {
          name  = "demo-api"
          image = var.demo_api_image

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "demo_api" {
  metadata {
    name      = "demo-api"
    namespace = "default"
  }

  spec {
    selector = {
      app = "demo-api"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "demo_api_internet" {
  depends_on = [helm_release.aws_load_balancer_controller]
  metadata {
    name      = "demo-api"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                 = "alb"
      "alb.ingress.kubernetes.io/load-balancer-name" = var.public_alb_name
      "alb.ingress.kubernetes.io/security-groups"    = var.public_alb_security_group_id
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/subnets"            = join(",", var.public_subnet_ids)
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTP\":80}]"
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
              name = kubernetes_service_v1.demo_api.metadata[0].name
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


resource "kubernetes_ingress_v1" "demo_api_internal" {
  depends_on = [helm_release.aws_load_balancer_controller]
  metadata {
    name      = "demo-api-internal"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                 = "alb"
      "alb.ingress.kubernetes.io/load-balancer-name" = var.private_alb_name
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTP\":80}]"
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
              name = kubernetes_service_v1.demo_api.metadata[0].name
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
