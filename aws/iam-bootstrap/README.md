# Hand-maintained IAM

Three policies that Terraform cannot own, with `apply.sh` to publish them.
Terraform cannot grant itself its own permissions, and a policy that bounds
`terraform-homelab` must sit where that user cannot rewrite it. All three are on
path `/`, while everything Terraform manages is on `/homelab/`.

| Policy | Purpose |
| --- | --- |
| `terraform-homelab-iam` | what the Terraform user may do to IAM, SNS and SES |
| `terraform-homelab-storage` | its S3 access, in place of `AmazonS3FullAccess` |
| `homelab-consumer-boundary` | the ceiling on every `homelab-*` user |

The account id is not in the JSON files, this repo is public. `apply.sh`
substitutes `ACCOUNT_ID` from `sts get-caller-identity`.

## Usage

`diff` and `verify` run as `terraform-homelab`. `push` and `attach` need admin,
which means attaching `AdministratorAccess` to `terraform-homelab` in the
console and **detaching it again afterwards**; `verify` refuses to run while it
is still there, because it would turn every check green.

```sh
./apply.sh diff      # what differs between these files and the account
./apply.sh push      # publish every file as the new default version
./apply.sh attach    # give terraform-homelab exactly its two policies
./apply.sh verify    # the escalation chain must stay dead
```

## Rules that are easy to get wrong

**Widen the boundary before handing out the permission.** A new consumer needs
its bucket in `homelab-consumer-boundary` first and its own policy second,
otherwise it is without the permission in between. Forgetting the boundary
answers `AccessDenied` while the Terraform policy looks perfectly correct.

**`homelab-*` is ten users, not the eight in `iam-backup-consumers.tf`.** The two
SES senders in `ses-mail.tf` carry the prefix too, which is why the boundary
allows `ses:SendRawEmail`.

**`terraform-homelab-storage` names buckets, not patterns.** A new bucket has to
be added here or `plan` fails on the first read. Its first statement lists only
bare bucket ARNs, so `s3:Get*` and `s3:Put*` cover bucket configuration while no
object action can match. Object access exists for the state bucket alone, and
`haushelden-wordpress-backup` is out of reach entirely.

**The state lock is an S3 object**, `<key>.tflock` next to the state, so
`use_lockfile` needs nothing beyond the `StateObjects` statement. The DynamoDB
table `terraform-state-lock` is left over from the years without locking and is
referenced by nothing.

**Scoping S3 does not make the backups safe from this key.** Terraform has to be
able to configure the buckets it manages, so `s3:PutLifecycleConfiguration` and
`s3:PutBucketVersioning` are in there. A lifecycle rule expiring everything
tomorrow does the damage that `DeleteObject` no longer can. Closing that means
Object Lock, not IAM.

**A policy keeps at most five versions.** `push` prunes the oldest
non-default one, so the version history is not an archive.

**`aws iam create-policy --description` is final.** No API changes it, only
delete and recreate, which means detaching it from every user first.
