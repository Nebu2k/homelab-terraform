variable "kubeconfig_path" {
  description = "kubeconfig of the Talos cluster. Gitignored, contains only this cluster."
  type        = string
  default     = "../../kubernetes-homelab/talos/clusterconfig/kubeconfig"
}

variable "homelab_repo_path" {
  description = "Checkout of kubernetes-homelab, source of the chart version and values"
  type        = string
  default     = "../../kubernetes-homelab"
}
