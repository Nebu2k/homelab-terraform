# The Postfix on the Proxmox host, pointed at SES. Its mails are the only
# signal for smartd and cron.daily failures, the alert rules cover the cluster
# but no Proxmox metric.
#
# Without a relay Postfix delivers by itself, and the local resolver answers
# elmstreet79.de with the Traefik VIP. Nothing has arrived that way.
#
# The SMTP password comes from the aws stack and therefore also ends up in this
# state.

data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    bucket = "homelab-elmstreet79-terraform-state"
    key    = "homelab/aws/terraform.tfstate"
    region = "eu-central-1"
  }
}

locals {
  ses_relay_host = "email-smtp.eu-west-1.amazonaws.com"
  ses_relay_port = 587
  # Inside the verified domain, unlike root@proxmox.elmstreet79.de.
  ses_sender = "proxmox@elmstreet79.de"
}

# Runs on the access key id, so a rotation in the aws stack reaches the host.
resource "terraform_data" "pve_postfix_relay" {
  triggers_replace = {
    script = sha256(templatefile("${path.module}/postfix/relay.sh.tftpl", {
      relay_host = local.ses_relay_host
      relay_port = local.ses_relay_port
      sender     = local.ses_sender
    }))
    access_key = data.terraform_remote_state.aws.outputs.ses_smtp_user
  }

  # Key explicitly, not through the agent, as in lxc-blocky.tf.
  connection {
    type        = "ssh"
    host        = regex("^https?://([^:/]+)", var.proxmox_endpoint)[0]
    user        = var.proxmox_ssh_username
    private_key = file(pathexpand(var.proxmox_ssh_private_key))
    agent       = false
  }

  # content instead of source: the credentials are not written to disk here.
  provisioner "file" {
    content     = "[${local.ses_relay_host}]:${local.ses_relay_port} ${data.terraform_remote_state.aws.outputs.ses_smtp_user}:${data.terraform_remote_state.aws.outputs.ses_smtp_password}\n"
    destination = "/etc/postfix/sasl_passwd"
  }

  provisioner "file" {
    content = templatefile("${path.module}/postfix/relay.sh.tftpl", {
      relay_host = local.ses_relay_host
      relay_port = local.ses_relay_port
      sender     = local.ses_sender
    })
    destination = "/root/postfix-relay.sh"
  }

  provisioner "remote-exec" {
    inline = ["sh /root/postfix-relay.sh"]
  }
}
