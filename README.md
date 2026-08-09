# Homelab Terraform

Infrastructure as Code for everything in my homelab that lives *outside* the
Kubernetes cluster: the Proxmox VMs it runs next to, the public DNS that points
at it, and the AWS side of its offsite backups.

The cluster itself is a separate repo, [kubernetes-homelab](https://github.com/Nebu2k/kubernetes-homelab),
managed via GitOps with ArgoCD. The two are deliberately split: ArgoCD reconciles
the cluster continuously, while everything here is applied by hand from a
workstation, because it touches hypervisor, registrar and cloud account.

## Stacks

Four independent root modules, each with its own state file. No cross-stack
`remote_state` lookups, the coupling between them is documented in comments
instead.

| Stack | Manages | Provider |
|-------|---------|----------|
| [`proxmox/`](proxmox/) | The Talos control plane VM on the Proxmox host | `bpg/proxmox` |
| [`cloudflare/`](cloudflare/) | Public DNS records for the exposed services | `cloudflare/cloudflare` |
| [`aws/`](aws/) | S3 buckets and IAM users for the offsite backups | `hashicorp/aws` |
| [`argocd-talos/`](argocd-talos/) | The ArgoCD release that bootstraps the cluster | `hashicorp/helm` |

State lives in a versioned S3 bucket, one key per stack
(`homelab/<stack>/terraform.tfstate`). The bucket itself was created by hand and
is not managed here, for the usual chicken-and-egg reason.

`.terraform.lock.hcl` **is** committed, one per stack. It used to be gitignored,
which left the provider version to whatever satisfied the range in
`required_providers` at the time of the `init`. The ranges here are wide on
purpose, so that anything below a major stays quiet, and the lock file is what
turns that into a reproducible version instead of a lottery. The files carry
`darwin_arm64` hashes only, because that is the only place these stacks are ever
applied from. Add a platform with `terraform providers lock -platform=linux_amd64`
before running them anywhere else.

## Usage

```bash
cd aws          # or cloudflare, proxmox, argocd-talos
terraform init
terraform plan
terraform apply
```

Credentials never live in the repo:

* **AWS**: taken from the CLI environment (`~/.aws`, profile `default`). The
  same credentials back the S3 state backend of all four stacks, so there is no
  variable for them.
* **Proxmox / Cloudflare**: non-secret values go into `terraform.tfvars` (gitignored,
  see the `.example` files), secrets come from `TF_VAR_*` environment variables.
* **Talos cluster**: no credential at all. `argocd-talos/` reads the kubeconfig
  that `talosctl` generated under `kubernetes-homelab/talos/clusterconfig/`.

## proxmox/

One resource pair: the Talos `nocloud` image pulled from the Image Factory, and
the single control plane VM `talos-cp-1` (`.20`, vmid 110) cloned from it.

That is the whole stack now. It used to carry a `vm-module` that built cloud-init
VMs from cloud images, plus definitions for Arch, MinIO, Windows and a Proxmox
Backup Server. All of them are gone, and the reasons are in the git history
rather than in commented-out blocks: MinIO lost its purpose when Longhorn started
backing up to the UniFi NAS over CIFS, and the rest were retired one by one as
the cluster took over their jobs.

The Talos VMs deliberately do *not* go through a module. Nothing a cloud-init
module offers applies: Talos has no shell, no package manager and no user
accounts. Its entire node configuration is a machine config under
`kubernetes-homelab/talos/`, applied with `talosctl`.

The two remaining Talos control plane nodes are bare metal, `raspi5` and
`prodesk`, and are therefore not in this stack at all. `talos-cp-1` is the last
one on the hypervisor, and it is a pet: the RTL-SDR stick is passed through to
it by vendor/product ID, so `readsb` is pinned to this node by `nodeSelector`.
The sizing comments in [`variables.tf`](proxmox/variables.tf) are worth reading
before changing memory or disk, both numbers are derived from a specific failure
scenario rather than from what happened to be free.

## cloudflare/

The exposure model is one variable:

```hcl
public_hosts = ["www", "dreambox", "homeassistant", "plex", "teslamate"]
```

Each entry becomes a `CNAME <host> -> <dyndns target>`, DNS-only, never proxied.
The DynDNS name tracks the home IP, a single 80/443 port-forward reaches Traefik,
and Traefik routes by Host header and terminates TLS with a Let's Encrypt
wildcard certificate. Because a CNAME inherits both A and AAAA of its target,
public access is dual-stack for free.

Anything *not* in that list has no public record at all and resolves only
internally, through a split-horizon wildcard that rewrites `*.<domain>` to
Traefik. Making a service public is therefore a one-line diff, and so is taking
it off the internet again.

The apex is a CNAME too. Cloudflare flattens it to A/AAAA at the zone root and
lets it coexist with the MX and TXT records, so the mail setup stays untouched.

## aws/

Offsite backups for four consumers, one bucket each, all in `eu-central-1`, all
with public access blocked, SSE-S3 (AES256) and lifecycle rules:

| Bucket | Contents | Versioning | Retention |
|--------|----------|-----------|-----------|
| `homelab-etcd-snapshots-*` | etcd snapshots from the three control plane nodes | Enabled | 28 kept per node, lifecycle caps at 30 days |
| `homelab-teslamate-backup` | `pg_dump` of the Teslamate database | Enabled | `daily/` 30 days, `monthly/` 365 days |
| `homelab-homeassistent-*` | Home Assistant backup tars | Disabled, on purpose | HA drives its own depth, monthly archive 180 days |
| `homelab-paperless-backup` | paperless-ngx `document_exporter` output | Enabled | none yet, the concept is still open |

### Two decisions worth knowing before changing anything here

**One IAM user per consumer, not one shared key.** They need different rights,
and that is the whole point of the split: only Home Assistant and k3s get
`DeleteObject`, because both run their own retention. None of them gets
`DeleteObjectVersion`. On the versioned buckets that is what makes versioning
actually worth something: a compromised cluster can hide a backup behind a
delete marker, but it cannot destroy it.

**There is no `aws_iam_access_key` resource, and there must not be one.** The
secret key would land in the state file and the state bucket would become a
credential store. Keys are created once in the console and delivered into the
cluster with `kubeseal`. This is backed by the Terraform user's own bootstrap
policy, which grants no `iam:CreateAccessKey`, so adding the resource does not
just weaken the design, it fails at apply time with `AccessDenied`. That
bootstrap policy is itself out of band by necessity: Terraform cannot grant
itself its own permissions.

The `outputs.tf` here is written to be read, not just consumed. It prints the
retention state of every bucket, the flags that belong on each control plane
node, and which Kubernetes secret every IAM user's key is supposed to end up in.

**Stale in this stack:** the comments and the etcd output still describe the k3s
mechanism, where `--etcd-s3-*` flags on the `k3s.service` unit made k3s upload
its own snapshots. The cluster is Talos now, and the uploads come from three
CronJobs in `kubernetes-homelab/manifests/etcd-backup/`, one per control plane
node, every twelve hours. The buckets, the IAM split and the lifecycle rules are
all unaffected, only the description of who writes into the bucket is out of
date.

## argocd-talos/

A single `helm_release` for ArgoCD, and nothing else. It exists as its own stack
rather than as a fourth file somewhere because the target cluster is decided by
`var.kubeconfig_path`, which points at the `talosctl`-generated kubeconfig. That
file can only reach the Talos cluster, which is the actual safeguard, and it is
why an accidental apply cannot hit the wrong cluster.

The root Application is deliberately *not* applied here: a `kubernetes_manifest`
needs its CRD to exist at plan time, and the `Application` CRD only shows up once
this release is installed. The `next_step` output prints the one `kubectl apply`
that closes the loop.

## A note on the comments

Comment density in this repo is well above average, and that is intentional.
Most of it is not explaining *what* a resource does, it records why something is
shaped the way it is, and what broke when it was shaped differently: why
`description` on an `aws_iam_policy` is `ForceNew` and quietly detaches your
policy, why `ListBucket` belongs on the bare bucket ARN and fails silently with
a `/*`, why the etcd retention has to be steered through
`--etcd-snapshot-retention`. A homelab is exactly the kind of system you touch
every few months, and by then the reasoning is gone. Those comments are the
actual documentation, this README is the map.
