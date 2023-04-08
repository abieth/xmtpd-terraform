variable "name" {}
variable "kubeconfig_path" { default = ".xmtp/kubeconfig.yaml" }
variable "node_container_image" {}
variable "nodes" {
  type = list(object({
    name                 = string
    node_id              = string
    p2p_public_address   = string
    p2p_persistent_peers = list(string)
    store_type           = optional(string, "mem")
  }))
}
variable "node_keys" {
  type      = map(string)
  sensitive = true
}
variable "enable_chat_app" { default = true }
variable "enable_monitoring" { default = true }
variable "num_xmtp_node_pool_nodes" { default = 2 }
variable "ingress_http_port" { default = 80 }
variable "ingress_https_port" { default = 443 }