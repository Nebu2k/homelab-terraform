# Homelab Terraform

Infrastructure as Code for the parts of my homelab that live *outside* the
Kubernetes cluster: the Proxmox guests next to it, the public DNS that points at
it, the DNS and mail of the website zones, the AWS side of its offsite backups,
and the ArgoCD release that bootstraps it.

The cluster itself is a separate repo, [kubernetes-homelab](https://github.com/Nebu2k/kubernetes-homelab),
managed via GitOps with ArgoCD. Everything here is applied by hand from a
workstation.

## Stacks

Five independent root modules, each with its own state file.

| Stack | Manages | Provider |
| ----- | ------- | -------- |
| [`proxmox/`](proxmox/) | The Talos control plane VM and the Blocky LXC on the Proxmox host | `bpg/proxmox` |
| [`cloudflare/`](cloudflare/) | Public DNS records for the exposed services | `cloudflare/cloudflare` |
| [`websites/`](websites/) | Redirects and mail records of the five website zones | `cloudflare/cloudflare` |
| [`aws/`](aws/) | S3 buckets, IAM users and the SES identities | `hashicorp/aws` |
| [`argocd-talos/`](argocd-talos/) | The ArgoCD release that bootstraps the cluster | `hashicorp/helm` |

Two of them read the `aws` state through `terraform_remote_state`: `websites`
for the DKIM tokens of the SES identities, `proxmox` for the SMTP credentials
of the relay. Both need `aws` applied first.

State lives in a versioned S3 bucket, one key per stack
(`homelab/<stack>/terraform.tfstate`), locked with native S3 conditional writes
(`use_lockfile`, no DynamoDB table). The bucket is not managed here.

`.terraform.lock.hcl` is committed, one per stack. The version ranges in
`required_providers` are wide, so the lock file is what pins the actual provider
version. The files carry `darwin_arm64` hashes only; add a platform with
`terraform providers lock -platform=linux_amd64` before applying from anywhere
else.

## Usage

```bash
cd aws          # or cloudflare, websites, proxmox, argocd-talos
terraform init
terraform plan
terraform apply
```

Credentials are not in the repo:

* **AWS**: taken from the CLI environment (`~/.aws`, profile `default`). The
  same credentials back the S3 state backend of every stack, so there is no
  variable for them.
* **Proxmox / Cloudflare**: non-secret values go into `terraform.tfvars`
  (gitignored, see the `.example` files), secrets come from `TF_VAR_*`
  environment variables.
* **Talos cluster**: no credential. `argocd-talos/` reads the kubeconfig that
  talhelper generated under `kubernetes-homelab/talos/clusterconfig/`.

## proxmox/

Two guests. The Talos control plane VM, cloned from a `nocloud` image pulled
from the Image Factory; the cluster's two other control plane nodes run on bare
metal and are not part of this stack. And the Blocky LXC, the second resolver of
the house: Alpine template, config snippets and provisioning script all in the
stack, so it comes back from nothing. It covers the cluster instance
complementarily, one resolver in one place would be a single point of failure
for every client in the house.

Talos deliberately does not go through a VM module. It has no shell, no package
manager and no user accounts, so there is nothing for cloud-init to do. The node
configuration is a machine config under `kubernetes-homelab/talos/`, applied
with `talosctl`.

The VM has an RTL-SDR stick passed through by vendor/product ID, and `readsb` is
pinned to it by `nodeSelector`. Memory and disk sizing are documented in
[`variables.tf`](proxmox/variables.tf); both have constraints attached, and
changing memory requires stopping the VM.

## cloudflare/

The exposure model is one variable:

```hcl
public_hosts = ["homeassistant", "plex"]
```

Each entry becomes a `CNAME <host> -> <dyndns target>`, DNS-only, never proxied.
The DynDNS name tracks the home IP, a single 80/443 port-forward reaches Traefik,
and Traefik routes by Host header and terminates TLS with a Let's Encrypt
wildcard certificate. Because a CNAME inherits both A and AAAA of its target,
public access is dual-stack.

Anything *not* in that list has no public record at all and resolves only
internally, through a split-horizon wildcard that rewrites `*.<domain>` to
Traefik. Making a service public is a one-line diff, and so is taking it off the
internet again.

The apex and `www` are deliberately absent: both are custom domains of the
`elmstreet79-de` Worker, and wrangler refuses to deploy over a record it did not
create. Their mail records live in the `websites` stack.

## aws/

Offsite backups for five consumers, one bucket each, all in `eu-central-1`, all
with public access blocked, SSE-S3 (AES256) and lifecycle rules:

| Bucket | Contents | Versioning | Retention |
| ------ | -------- | ---------- | --------- |
| `homelab-etcd-snapshots-*` | etcd snapshots from the three control plane nodes | Enabled | lifecycle 30 days, noncurrent 30 days |
| `homelab-teslamate-backup` | `pg_dump` of the Teslamate database | Enabled | `daily/` 30 days, `monthly/` 365 days |
| `homelab-mealie-backup` | ZIPs from Mealie's built-in backup (database and recipe images) | Enabled | `daily/` 30 days, `monthly/` 365 days |
| `homelab-homeassistent-*` | Home Assistant backup tars | Disabled | HA drives its own depth, monthly archive 180 days |
| `homelab-paperless-backup` | paperless-ngx `document_exporter` output | Enabled | none, multipart abort only |

The etcd snapshots are uploaded by three CronJobs in
`kubernetes-homelab/manifests/etcd-backup/`, one per control plane node, twice a
day. Talos does not upload snapshots itself, it only hands them out over its
API.

### Two properties worth knowing before changing anything here

**One IAM user per consumer, not one shared key.** They need different rights:
only Home Assistant gets `DeleteObject`, because it runs its own retention. None
of them gets `DeleteObjectVersion`. On the versioned buckets that is what makes
versioning worth something: a compromised cluster can hide a backup behind a
delete marker, but it cannot destroy it.

**Every access key is a Terraform resource**, the eight backup and alert
consumers in `iam-access-keys.tf` and the SES sender alongside its identity. The price is that both halves of each key sit in the state, and
because the state bucket is versioned, a rotation only stops the current version
from naming the old secret, it never removes it. What it buys is one place that
says which key is current and where it belongs. `terraform output -json
backup_consumer_secrets` is what fills the `*-unsealed.yaml` files before
`kubeseal`; the Home Assistant backup integration is the one consumer whose key
is typed in by hand instead.

Rotating one consumer is `terraform apply -replace=aws_iam_access_key.<name>`.
That deletes the old key in the same apply, so reseal right after: every
consumer is a CronJob or a retrying sidecar, so the gap costs a run at most, but
it should not land in a backup window.

The bootstrap policy of the Terraform user is out of band by necessity:
Terraform cannot grant itself its own permissions.

The `outputs.tf` here prints the retention state of every bucket and which
Kubernetes secret each IAM user's key belongs in.

### Two more things this stack owns

The **SNS topic** the cluster's Alertmanager publishes into, mail subscription
included. It is the only alert path in the homelab, Gatus and Grafana
deliberately do not notify on their own.

The **permissions boundary** every `homelab-*` user carries. It is what keeps a
leaked `terraform-homelab` key from becoming an account takeover, and it is a
third place to touch when a consumer is added, next to the user policy here and
the SealedSecret in `kubernetes-homelab`. A bucket missing from the boundary
answers `AccessDenied` while the user policy looks perfectly correct.

### SES

One domain sends through SES in `eu-west-1`, with Easy DKIM and a custom MAIL
FROM: seb-it.com for the mail client, because Cloudflare Email Routing only
forwards and cannot send. The matching DNS records live in the `websites` stack.

Its access key sits next to the identity rather than in `iam-access-keys.tf`,
because it is not a plain key: SMTP does not take the secret key but an HMAC of
it over the region, and Terraform is the only thing here that derives it; the
SES console would instead create an IAM user of its own. The alias
`aws.ireland` on those resources is what decides the region of that HMAC, IAM
being global does not change it.

## websites/

The five website zones: the canonical host redirect per zone and the mail
records of all of them. It deploys nothing, every site ships itself with
`wrangler` from its own repo, and the custom domains stay in that repo's
`wrangler.jsonc`. The token needs more than the obvious scopes, and existing
redirect rules have to be imported instead of applied over. Both are written up
in [`websites/README.md`](websites/README.md).

## argocd-talos/

A single `helm_release` for ArgoCD. The target cluster is decided by
`var.kubeconfig_path`, which points at the talhelper-generated kubeconfig; that
file can only reach the Talos cluster.

The root Application is not applied here: a `kubernetes_manifest` needs its CRD
at plan time, and the `Application` CRD only exists once this release is
installed. The `next_step` output prints the `kubectl apply` that closes the
loop.
