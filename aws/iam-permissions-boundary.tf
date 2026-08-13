# The permissions boundary every homelab-* user carries. It caps what such a
# user can do regardless of which policy is attached, and it is what keeps a
# leaked terraform-homelab key from becoming an account takeover: that user may
# create a policy under policy/homelab/* with arbitrary content, attach it to a
# homelab-* user and create an access key for it. All three calls are allowed.
#
# The boundary policy itself is not in Terraform and sits at path "/", not
# "/homelab/", both on purpose. terraform-homelab may rewrite anything under
# policy/homelab/* through CreatePolicyVersion, so a boundary living there
# would be one call away from being switched off. It is maintained by hand with
# admin credentials, like the bootstrap policy "terraform-homelab-iam".
#
# It is a third place to touch when a consumer is added, next to the user
# policy here and the SealedSecret in kubernetes-homelab. A bucket missing from
# the boundary answers AccessDenied while the user policy looks correct.

data "aws_caller_identity" "current" {}

locals {
  homelab_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/homelab-consumer-boundary"
}
