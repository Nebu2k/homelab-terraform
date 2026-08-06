# Homelab Terraform

Infrastructure as Code for everything in my homelab that lives *outside* the
Kubernetes cluster: the Proxmox VMs it runs next to, the public DNS that points
at it, and the AWS side of its offsite backups.

The cluster itself is a separate repo, [kubernetes-homelab](https://github.com/Nebu2k/kubernetes-homelab),
managed via GitOps with ArgoCD. The two are deliberately split: ArgoCD reconciles
the cluster continuously, while everything here is applied by hand from a
workstation, because it touches hypervisor, registrar and cloud account.

## Stacks

Three independent root modules, each with its own state file. No cross-stack
`remote_state` lookups, the coupling between them is documented in comments
instead.

| Stack | Manages | Provider |
|-------|---------|----------|
| [`proxmox/`](proxmox/) | VMs on the Proxmox host, cloud-init driven | `bpg/proxmox` |
| [`cloudflare/`](cloudflare/) | Public DNS records for the exposed services | `cloudflare/cloudflare` |
| [`aws/`](aws/) | S3 buckets and IAM users for the offsite backups | `hashicorp/aws` |

State lives in a versioned S3 bucket, one key per stack
(`homelab/<stack>/terraform.tfstate`). The bucket itself was created by hand and
is not managed here, for the usual chicken-and-egg reason.

## Usage

```bash
cd aws          # or cloudflare, or proxmox
terraform init
terraform plan
terraform apply
```

Credentials never live in the repo:

* **AWS**: taken from the CLI environment (`~/.aws`, profile `default`). The
  same credentials back the S3 state backend of all three stacks, so there is no
  variable for them.
* **Proxmox / Cloudflare**: non-secret values go into `terraform.tfvars` (gitignored,
  see the `.example` files), secrets come from `TF_VAR_*` environment variables.

## proxmox/

A single `vm-module` builds a cloud-init VM from a downloaded cloud image:
static IP, SSH key, disk, and a rendered user-data snippet. Each VM is one small
file at the root that calls the module with its parameters.

Live right now is one Arch VM. The Proxmox Backup Server, MinIO and Windows
definitions are kept as commented-out blueprints rather than deleted, together
with the reason each one was retired. MinIO is the interesting one: its provider
pointed at a fixed address and got initialised on *every* plan, so once the VM
was stopped it would have blocked the whole stack. The bucket resource was
removed with `terraform state rm` instead of destroyed, to keep the data on the
VM disk.

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
| `homelab-etcd-snapshots-*` | k3s etcd snapshots from the three server nodes | Enabled | k3s keeps 28 per node, lifecycle caps at 30 days |
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
retention state of every bucket, the exact `--etcd-s3-*` flags that belong in
each k3s unit, and which Kubernetes secret every IAM user's key is supposed to
end up in.

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
