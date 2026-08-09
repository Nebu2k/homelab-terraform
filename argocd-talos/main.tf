# ArgoCD im Talos-Cluster
#
# Eigener Stack und eigener State-Key, NICHT ein Stack mit umgebogenem
# kubeconfig. Solange zwei Cluster parallel laufen, waere ein "apply" gegen den
# falschen Kontext ein Totalschaden am jeweils anderen. Der k3s-Seite gehoert
# spaeter ein eigenes Verzeichnis (argocd-k3s/), das das bestehende ArgoCD per
# "terraform import helm_release.argocd argocd/argocd" einsammelt. Erst wenn es
# das gibt, lohnt sich ein gemeinsames Modul; fuer einen Stack waere es Ballast.
#
# Das Cluster-Ziel steckt in der kubeconfig, nicht in einem Kontextnamen: die
# Datei unter kubernetes-homelab/talos/clusterconfig/ enthaelt ausschliesslich
# das Talos-Cluster und kann das k3s-Cluster gar nicht erreichen. Das ist der
# eigentliche Schutz.

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

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  # Warten, bis die Pods stehen. Ohne das meldet der Apply Erfolg, waehrend der
  # Server noch startet, und der anschliessende root-app-Apply laeuft ins Leere.
  wait    = true
  timeout = 900

  # resource.exclusions: ArgoCDs eingebaute Default-Liste, aber OHNE core/
  # Endpoints. Gefunden am 2026-08-09 beim Umzug von external-services.
  #
  # Ab ArgoCD 3.0 stehen Endpoints und EndpointSlice per Default auf der
  # Ausschlussliste. Ausgeschlossen heisst nicht "wird nicht angezeigt", sondern
  # "existiert fuer ArgoCD nicht": die neun handgeschriebenen Endpoints-Objekte
  # aus manifests/external-services/ werden nie angelegt, und die App meldet
  # trotzdem Synced/Healthy. Sichtbar war das nur daran, dass Traefik fuer
  # pve/unifi/plex 503 lieferte, weil hinter den selektorlosen Services nichts
  # stand. Im k3s-Cluster faellt es nicht auf: dort stammen die Objekte aus der
  # Zeit vor 3.0 und werden aus demselben Grund auch nicht geprunt.
  #
  # Nur core/Endpoints kommt zurueck, discovery.k8s.io/EndpointSlice bleibt
  # draussen. Die Slices erzeugt der Mirroring-Controller selbst, sie gehoeren
  # niemandem im Repo, und sie sind die Masse.
  #
  # Preis: die Liste ist damit auf den Stand von ArgoCD 3.5.0 eingefroren.
  # Bei einem ArgoCD-Major pruefen, ob upstream neue Ausschluesse dazugekommen
  # sind ("argocd admin settings resource-overrides list" bzw. das
  # Default-argocd-cm der neuen Version), und hier nachziehen.
  values = [<<-EOT
    configs:
      cm:
        resource.exclusions: |
          - apiGroups:
            - discovery.k8s.io
            kinds:
            - EndpointSlice
          - apiGroups:
            - coordination.k8s.io
            kinds:
            - Lease
          - apiGroups:
            - authentication.k8s.io
            - authorization.k8s.io
            kinds:
            - SelfSubjectReview
            - TokenReview
            - LocalSubjectAccessReview
            - SelfSubjectAccessReview
            - SelfSubjectRulesReview
            - SubjectAccessReview
          - apiGroups:
            - certificates.k8s.io
            kinds:
            - CertificateSigningRequest
          - apiGroups:
            - cert-manager.io
            kinds:
            - CertificateRequest
          - apiGroups:
            - cilium.io
            kinds:
            - CiliumIdentity
            - CiliumEndpoint
            - CiliumEndpointSlice
          - apiGroups:
            - kyverno.io
            - reports.kyverno.io
            - wgpolicyk8s.io
            kinds:
            - PolicyReport
            - ClusterPolicyReport
            - EphemeralReport
            - ClusterEphemeralReport
            - AdmissionReport
            - ClusterAdmissionReport
            - BackgroundScanReport
            - ClusterBackgroundScanReport
            - UpdateRequest
  EOT
  ]

  # Derselbe vollstaendige Wertesatz wie im k3s-Cluster ("helm get values
  # argocd"). Bewusst explizit statt --reuse-values: bei einem Chart-Major
  # schlagen neue Defaults sonst nicht sauber durch.
  #
  # server.insecure, weil Traefik TLS terminiert. Ohne das laeuft https auf
  # https und der Ingress bekommt ein 502.
  set = [
    {
      name  = "global.domain"
      value = var.argocd_domain
    },
    {
      name  = "configs.cm.url"
      value = "https://${var.argocd_domain}"
    },
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    # Hier stand bis zum 2026-08-09 ein "--load-restrictor LoadRestrictionsNone"
    # in kustomize.buildOptions. Gebraucht wurde es nur waehrend der
    # Parallelphase: clusters/talos/kustomization.yaml zog die
    # Application-Manifeste aus ../../apps/, und Kustomize verbietet
    # Datei-Referenzen oberhalb des Overlay-Verzeichnisses per Default.
    #
    # clusters/talos/ gibt es seit dem Abbau des k3s-Clusters nicht mehr, apps/
    # ist die einzige Liste, und keine kustomization.yaml im Repo zeigt noch
    # oberhalb ihres eigenen Verzeichnisses. Damit ist die Lockerung ersatzlos
    # entfallen: sie stehen zu lassen hiesse, eine Sicherheitsgrenze fuer einen
    # Grund offen zu halten, den es nicht mehr gibt.
  ]
}

# Die root-App wird bewusst NICHT hier ausgerollt. Ein kubernetes_manifest
# braucht die CRD schon zur Plan-Zeit, die Application-CRD entsteht aber erst
# mit diesem helm_release. Das ist ein Henne-Ei-Problem, das man nur mit einem
# zweiten Apply oder einem Fremdprovider loest. Stattdessen ein Einzeiler nach
# dem Apply, siehe Output unten.
output "next_step" {
  description = "Was nach dem Apply von Hand kommt"
  value       = <<-EOT

    ArgoCD laeuft. Jetzt die root-App ausrollen:

      KUBECONFIG=${var.kubeconfig_path} \
        kubectl apply -f ../../kubernetes-homelab/bootstrap/root-app-talos.yaml

    UI in der Parallelphase nur per Port-Forward: der Wildcard-Rewrite zeigt
    ${var.argocd_domain} weiter auf das k3s-Cluster.

      KUBECONFIG=${var.kubeconfig_path} \
        kubectl -n argocd port-forward svc/argocd-server 8080:80

    Initiales Admin-Passwort:

      KUBECONFIG=${var.kubeconfig_path} kubectl -n argocd get secret \
        argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

  EOT
}
