# ArgoCD in the Talos cluster, installed once for the bootstrap.
#
# After that ArgoCD manages itself through kubernetes-homelab/apps/argocd.yaml.
# This stack reads the chart version from that Application and the values from
# manifests/argocd/values.yaml, so the first install is exactly what the
# Application takes over, and it ignores the release from then on.
#
# Its own root module with its own state key. The target cluster comes from
# var.kubeconfig_path, which contains only this cluster, so an apply cannot
# reach any other one.

terraform {
  required_version = ">= 1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

locals {
  argocd_app = yamldecode(file("${var.homelab_repo_path}/apps/argocd.yaml"))
  argocd_chart = one([
    for s in local.argocd_app.spec.sources : s if try(s.chart, "") == "argo-cd"
  ])
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = local.argocd_chart.repoURL
  chart            = local.argocd_chart.chart
  version          = local.argocd_chart.targetRevision
  namespace        = "argocd"
  create_namespace = true

  # Wait for the pods to be ready. Without this the apply reports success while
  # the server is still starting, and the root-app apply that follows it fails.
  wait    = true
  timeout = 900

  values = [file("${var.homelab_repo_path}/manifests/argocd/values.yaml")]

  # The argocd Application owns the release once it has synced. Without this
  # the next apply would roll ArgoCD back to whatever the state remembers.
  lifecycle {
    ignore_changes = all
  }
}

# The root Application is not rolled out from here: a kubernetes_manifest needs
# its CRD at plan time, and the Application CRD only exists once this release is
# installed.
output "next_step" {
  description = "Manual step after the apply"
  value       = <<-EOT

    ArgoCD is up. Roll out the root app:

      KUBECONFIG=${var.kubeconfig_path} \
        kubectl apply -f ../../kubernetes-homelab/bootstrap/root-app-talos.yaml

    Initial admin password:

      KUBECONFIG=${var.kubeconfig_path} kubectl -n argocd get secret \
        argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

  EOT
}
