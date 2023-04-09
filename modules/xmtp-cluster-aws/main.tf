locals {
  node_pool_label_key = "node-pool"
  system_node_pool    = "xmtp-system"
  nodes_node_pool     = "xmtp-nodes"
  ingress_class_name  = "traefik"
  node_api_http_port  = 5001

  namespace = var.namespace
  stage     = var.stage
  name      = var.name
  fullname  = "${local.namespace}-${local.stage}-${local.name}"

  node_hostnames       = flatten([for node in var.nodes : [for hostname in var.hostnames : "${node.name}.${hostname}"]])
  chat_app_hostnames   = [for hostname in var.hostnames : "chat.${hostname}"]
  grafana_hostnames    = [for hostname in var.hostnames : "grafana.${hostname}"]
  jaeger_hostnames     = [for hostname in var.hostnames : "jaeger.${hostname}"]
  prometheus_hostnames = [for hostname in var.hostnames : "prometheus.${hostname}"]
}

data "aws_caller_identity" "current" {}

module "ecr_node_repo" {
  source  = "cloudposse/ecr/aws"
  version = "0.35.0"

  namespace  = local.namespace
  stage      = local.stage
  name       = local.name
  attributes = ["node"]

  force_delete = true
}

module "k8s" {
  source = "./k8s"

  namespace = local.namespace
  stage     = local.stage
  name      = local.name

  region                       = var.region
  availability_zones           = var.availability_zones
  vpc_cidr_block               = var.vpc_cidr_block
  kubernetes_version           = var.kubernetes_version
  enabled_cluster_log_types    = var.enabled_cluster_log_types
  cluster_log_retention_period = var.cluster_log_retention_period

  node_pools = [
    {
      name           = local.system_node_pool
      instance_types = ["t3.small"]
      desired_size   = 2
      labels = {
        (local.node_pool_label_key) = local.system_node_pool
      }
    },
    {
      name           = local.nodes_node_pool
      instance_types = ["t3.small"]
      desired_size   = 2
      labels = {
        (local.node_pool_label_key) = local.nodes_node_pool
      }
    }
  ]
}

module "system" {
  source     = "../xmtp-cluster/system"
  depends_on = [module.k8s]

  namespace            = "xmtp-system"
  node_pool_label_key  = local.node_pool_label_key
  node_pool            = local.system_node_pool
  ingress_class_name   = local.ingress_class_name
  ingress_service_type = "LoadBalancer"
}

module "tools" {
  source     = "../xmtp-cluster/tools"
  depends_on = [module.system]

  namespace            = "xmtp-tools"
  node_pool_label_key  = local.node_pool_label_key
  node_pool            = local.system_node_pool
  ingress_class_name   = local.ingress_class_name
  wait_for_ready       = false
  enable_chat_app      = var.enable_chat_app
  enable_monitoring    = var.enable_monitoring
  public_api_url       = "http://${var.hostnames[0]}"
  chat_app_hostnames   = local.chat_app_hostnames
  grafana_hostnames    = local.grafana_hostnames
  jaeger_hostnames     = local.jaeger_hostnames
  prometheus_hostnames = local.prometheus_hostnames
}

module "nodes" {
  source     = "../xmtp-cluster/nodes"
  depends_on = [module.system]

  namespace                 = "xmtp-nodes"
  container_image           = var.node_container_image
  node_pool_label_key       = local.node_pool_label_key
  node_pool                 = local.nodes_node_pool
  nodes                     = var.nodes
  node_keys                 = var.node_keys
  ingress_class_name        = local.ingress_class_name
  hostnames                 = var.hostnames
  node_api_http_port        = local.node_api_http_port
  storage_class_name        = "gp2"
  container_storage_request = "1Gi"
  container_cpu_request     = "10m"
  debug                     = true
  wait_for_ready            = false
  one_instance_per_k8s_node = false
}
