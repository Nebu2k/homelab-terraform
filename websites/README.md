# websites

The wiring around the personal and business websites, all of them Astro on
Cloudflare Workers with static assets. Separate from `cloudflare/`, which is
about homelab exposure and holds a token for a single zone.

## What Terraform does and does not do here

**Does:** the canonical host redirect per zone, a 301 from `www` to the apex or
the other way round, whichever `canonical` says. Since 2026-08-13 also the mail
records of all five zones, see `mail.tf`.

**Does not:** deploy anything. Since 2026-08-13 every site deploys itself from
`.github/workflows/deploy.yml` in its own repo, all five identical, with
`wrangler deploy` and a token in the repo secret `CF_API_TOKEN`. Cloudflare's
own build integration is not used any more: it could not be expressed in code
and handed out a per-project build token that only two of the five ever had.

Custom domains are deliberately left in each repo's `wrangler.jsonc` as well,
next to the code they belong to. Managing them here too would only make
Terraform and wrangler fight over the same record.

**Both hostnames never belong to the Worker.** Only the canonical one is a
custom domain; the other keeps a plain proxied record so the redirect rule in
this stack can answer it. Declaring both makes every deploy fail with error
100117, wrangler refuses to overwrite a record it did not create. That is what
broke homeworx.solutions when the workflows went in.

## Token

The token in `cloudflare/` only covers elmstreet79.de, this stack needs one
across every zone in `var.sites`:

- Zone, Zone, Read
- **Zone, Single Redirect, Edit.** Not "Transform Rules", which covers a
  different ruleset phase and leaves every read on a redirect ruleset answering
  "request is not authorized" while still happily listing them.
- **Zone, DNS, Edit.** Needed since `mail.tf` exists. Read alone is not
  obvious from the failure: reads succeed, `terraform plan` renders a full and
  correct diff, and only `apply` fails with `Authentication error (10000)` on
  every record. The message says "failed to create DNS record" even for records
  that are being imported and updated, so it points at the wrong thing.
- Zone Resources: include every zone listed in `terraform.tfvars`

Put it in `terraform.tfvars`, which is gitignored. `terraform.tfvars.example`
shows the shape.

## Adopting rules that already exist

seb-it.com, homeworx.solutions and haushelden-service.de were clicked together
by hand and have a redirect already. Import it instead of applying over it,
otherwise the rule is dropped and recreated and the site 404s in between:

```sh
terraform import 'cloudflare_ruleset.canonical_redirect["seb-it.com"]' zone/<zone_id>/<ruleset_id>
```

The ruleset id comes from the API, there is no way to see it in the dashboard:

```sh
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/<zone_id>/rulesets" \
  | python3 -m json.tool | grep -B3 http_request_dynamic_redirect
```

Run `terraform plan` after every import and expect it to come back clean. A
diff on `expression` or `target_url` means the hand-made rule was worded
differently, and that is worth reading before applying: the wording is the rule.

## Mail records

`mail.tf` holds MX, SPF, DMARC, DKIM and the SES MAIL FROM subdomain of all
five zones, generated from the live zones so the adoption starts at zero drift.
`mail-imports.tf` carries an `import` block per record and can be deleted after
the first successful apply.

Two traps are already worked into the file, both found the hard way:

- **`name` is relative for subdomains, absolute for the apex.** The provider
  stores `mail`, not `mail.seb-it.com`, and a full name forces replacement.
  Terraform then destroys and recreates the MX records of a zone, which is a
  gap in mail delivery, not a no-op.
- **`ttl` and `comment` come from the existing records, not from a
  convention.** The zones mix TTL 1 and 3600 and some records already carry a
  comment. Normalising them would touch 23 records for no reason and bury the
  one change that matters in the noise.

The only intended change on adoption is the apex SPF of haushelden-service.de
and homeworx.solutions. Both listed `amazonses.com` and `_spf.mx.cloudflare.net`
without either being reachable that way: Email Routing is off on those zones
(the MX point at iCloud), and SES sends with a custom MAIL FROM, so SPF is
evaluated against `mail.<domain>` and never against the apex. What remains is
`v=spf1 include:icloud.com ~all`.
