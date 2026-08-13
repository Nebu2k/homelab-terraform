#!/usr/bin/env bash
# Publishes the hand-maintained IAM policies in this directory.
#
#   ./apply.sh diff     what differs between these files and the account
#   ./apply.sh push     publish every file as the new default version
#   ./apply.sh attach   give terraform-homelab exactly its two policies
#   ./apply.sh verify   the escalation chain must stay dead
#
# "push" and "attach" need admin credentials, see README.md. "diff" and
# "verify" run as terraform-homelab.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BOUNDARY="arn:aws:iam::${ACCOUNT}:policy/homelab-consumer-boundary"

# Everything terraform-homelab is allowed to have. AmazonS3FullAccess and
# AmazonDynamoDBFullAccess used to sit here and reached every bucket in the
# account, including the offsite backups.
WANTED=(terraform-homelab-iam terraform-homelab-storage)

POLICIES=(terraform-homelab-iam homelab-consumer-boundary terraform-homelab-storage)

# The account id is deliberately not in the files, this repo is public.
render() { sed "s/ACCOUNT_ID/${ACCOUNT}/g" "${HERE}/$1.json"; }

arn_of() { echo "arn:aws:iam::${ACCOUNT}:policy/$1"; }

live_document() {
  local arn="$1" v
  v=$(aws iam get-policy --policy-arn "$arn" --query 'Policy.DefaultVersionId' --output text)
  aws iam get-policy-version --policy-arn "$arn" --version-id "$v" \
    --query 'PolicyVersion.Document' --output json
}

canonical() { python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), indent=2, sort_keys=True))'; }

# A policy holds at most five versions, so publishing needs room first.
prune() {
  local arn="$1" n oldest
  while :; do
    n=$(aws iam list-policy-versions --policy-arn "$arn" --query 'length(Versions)' --output text)
    [ "$n" -lt 5 ] && break
    oldest=$(aws iam list-policy-versions --policy-arn "$arn" \
      --query 'sort_by(Versions[?!IsDefaultVersion], &CreateDate)[0].VersionId' --output text)
    echo "  pruning $oldest"
    aws iam delete-policy-version --policy-arn "$arn" --version-id "$oldest"
  done
}

case "${1:-}" in
  diff)
    rc=0
    for p in "${POLICIES[@]}"; do
      arn=$(arn_of "$p")
      if ! aws iam get-policy --policy-arn "$arn" >/dev/null 2>&1; then
        echo "$p: does not exist yet"; rc=1; continue
      fi
      if diff -u <(live_document "$arn" | canonical) <(render "$p" | canonical) >/tmp/iam-diff.$$; then
        echo "$p: in sync"
      else
        echo "$p: differs"; cat /tmp/iam-diff.$$; rc=1
      fi
      rm -f /tmp/iam-diff.$$
    done
    exit $rc
    ;;

  push)
    for p in "${POLICIES[@]}"; do
      arn=$(arn_of "$p")
      doc=$(mktemp); render "$p" >"$doc"
      if aws iam get-policy --policy-arn "$arn" >/dev/null 2>&1; then
        # A policy holds five versions at most, so republishing an unchanged
        # document would push out history for nothing.
        if diff -q <(live_document "$arn" | canonical) <(canonical <"$doc") >/dev/null; then
          echo "$p unchanged"; rm -f "$doc"; continue
        fi
        prune "$arn"
        echo "$p -> $(aws iam create-policy-version --policy-arn "$arn" --set-as-default \
          --policy-document "file://$doc" --query 'PolicyVersion.VersionId' --output text)"
      else
        # Path / on purpose: terraform-homelab may rewrite anything under
        # policy/homelab/*, so a policy that bounds it cannot live there.
        echo "$p -> created $(aws iam create-policy --policy-name "$p" --path / \
          --policy-document "file://$doc" --query 'Policy.Arn' --output text)"
      fi
      rm -f "$doc"
    done
    ;;

  attach)
    # --output text separates with tabs, the membership test below needs spaces.
    have=$(aws iam list-attached-user-policies --user-name terraform-homelab \
      --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' ' ')
    for p in "${WANTED[@]}"; do
      arn=$(arn_of "$p")
      case " $have " in
        *" $arn "*) echo "$p already attached" ;;
        *) aws iam attach-user-policy --user-name terraform-homelab --policy-arn "$arn"
           echo "$p attached" ;;
      esac
    done
    # Detach second, so there is never a moment without the replacement.
    for arn in $have; do
      keep=no
      for p in "${WANTED[@]}"; do [ "$arn" = "$(arn_of "$p")" ] && keep=yes; done
      [ "$keep" = yes ] && continue
      aws iam detach-user-policy --user-name terraform-homelab --policy-arn "$arn"
      echo "${arn##*/} detached"
    done
    ;;

  verify)
    # AdministratorAccess would make every simulation below say "allowed".
    if aws iam list-attached-user-policies --user-name terraform-homelab \
         --query 'AttachedPolicies[].PolicyName' --output text | grep -q AdministratorAccess; then
      echo "ABORT: AdministratorAccess is still attached to terraform-homelab"
      exit 1
    fi

    echo "== escalation chain, all three must be denied =="
    aws iam simulate-principal-policy \
      --policy-source-arn "arn:aws:iam::${ACCOUNT}:user/terraform-homelab" \
      --action-names iam:CreateUser iam:AttachUserPolicy iam:DeleteUserPermissionsBoundary \
      --resource-arns "arn:aws:iam::${ACCOUNT}:user/homelab-mealie-backup" \
      --context-entries "ContextKeyName=iam:PolicyARN,ContextKeyType=string,ContextKeyValues=arn:aws:iam::${ACCOUNT}:policy/homelab/anything" \
      --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table

    echo "== the legitimate path must stay allowed =="
    aws iam simulate-principal-policy \
      --policy-source-arn "arn:aws:iam::${ACCOUNT}:user/terraform-homelab" \
      --action-names iam:CreateUser iam:AttachUserPolicy \
      --resource-arns "arn:aws:iam::${ACCOUNT}:user/homelab-mealie-backup" \
      --context-entries "ContextKeyName=iam:PolicyARN,ContextKeyType=string,ContextKeyValues=arn:aws:iam::${ACCOUNT}:policy/homelab/anything" \
                        "ContextKeyName=iam:PermissionsBoundary,ContextKeyType=string,ContextKeyValues=${BOUNDARY}" \
      --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table

    echo "== backup objects and foreign buckets must be out of reach =="
    aws iam simulate-principal-policy \
      --policy-source-arn "arn:aws:iam::${ACCOUNT}:user/terraform-homelab" \
      --action-names s3:DeleteObject s3:GetObject \
      --resource-arns "arn:aws:s3:::homelab-etcd-snapshots-elmstreet79/snapshot.db" \
      --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table
    aws iam simulate-principal-policy \
      --policy-source-arn "arn:aws:iam::${ACCOUNT}:user/terraform-homelab" \
      --action-names s3:DeleteBucket s3:ListBucket \
      --resource-arns "arn:aws:s3:::haushelden-wordpress-backup" \
      --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table

    echo "== boundary on every homelab-* user =="
    aws iam list-users --query "Users[?starts_with(UserName,'homelab-')].UserName" --output text |
      tr '\t' '\n' | while read -r u; do
        printf '%-34s %s\n' "$u" \
          "$(aws iam get-user --user-name "$u" \
             --query 'User.PermissionsBoundary.PermissionsBoundaryArn' --output text | sed 's|.*policy/||')"
      done
    ;;

  *) echo "usage: $0 diff|push|attach|verify" >&2; exit 2 ;;
esac
