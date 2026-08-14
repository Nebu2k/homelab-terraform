# websites

The wiring around the personal and business websites, all of them Astro on
Cloudflare Workers with static assets. Separate from `cloudflare/`, which is
about homelab exposure and holds a token for a single zone.

## What Terraform does and does not do here

**Does:** the canonical host redirect per zone, a 301 from `www` to the apex or
the other way round, whichever `canonical` says, and the mail records of all
five zones in `mail.tf`.

**Does not:** deploy anything. Every site deploys itself from
`.github/workflows/deploy.yml` in its own repo, all five identical, with
`wrangler deploy` and a token in the repo secret `CF_API_TOKEN`. Cloudflare's
own build integration is unused on purpose, it cannot be expressed in code.

Custom domains stay in each repo's `wrangler.jsonc`, next to the code they
belong to. Managing them here as well would only make Terraform and wrangler
fight over the same record.

**Both hostnames never belong to the Worker.** Only the canonical one is a
custom domain, the other keeps a plain proxied record so the redirect rule in
this stack can answer it. Declaring both makes every deploy fail with error
100117, wrangler refuses to overwrite a record it did not create.

## Token

The token in `cloudflare/` only covers elmstreet79.de, this stack needs one
across every zone in `var.sites`:

- Zone, Zone, Read
- **Zone, Single Redirect, Edit.** Not "Transform Rules", which covers a
  different ruleset phase and leaves every read on a redirect ruleset answering
  "request is not authorized" while still happily listing them.
- **Zone, DNS, Edit.** Read alone fails in a way that points elsewhere: reads
  succeed, `terraform plan` renders a full and correct diff, and only `apply`
  fails with `Authentication error (10000)`, reporting "failed to create DNS
  record" even for records that are only being imported or updated.
- Zone Resources: include every zone listed in `terraform.tfvars`

Put it in `terraform.tfvars`, which is gitignored. `terraform.tfvars.example`
shows the shape.

`both_hosts_on_worker` takes `/.well-known/security.txt` out of the redirect so
the file answers 200 on both hostnames. It only holds where both are custom
domains on the Worker, which is elmstreet79.de alone; anywhere else the request
skips the redirect and reaches nothing.

## Adopting rules that already exist

A zone that already carries a redirect rule has to be imported, not applied
over, otherwise the rule is dropped and recreated and the site 404s in between:

```sh
terraform import 'cloudflare_ruleset.canonical_redirect["seb-it.com"]' zone/<zone_id>/<ruleset_id>
```

The ruleset id comes from the API, the dashboard does not show it:

```sh
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/<zone_id>/rulesets" \
  | python3 -m json.tool | grep -B3 http_request_dynamic_redirect
```

`terraform plan` after an import has to come back clean. A diff on `expression`
or `target_url` means the existing rule is worded differently, and the wording
is the rule.

## Mail records

`mail.tf` holds MX, SPF, DMARC and DKIM of all five zones. Four of them run on
iCloud alone and carry six records each, identical apart from their own keys
and identifiers. Only seb-it.com sends through SES and carries a MAIL FROM
subdomain plus three SES DKIM CNAMEs on top, because it receives through Email
Routing and cannot answer as itself otherwise.

Its DKIM tokens come from `terraform_remote_state` on the `aws` stack, which
owns the identity in `aws/ses-mail.tf`. That stack has to be applied first,
otherwise the output does not exist yet and the plan fails here.

haushelden-service.de and homeworx.solutions carry `sp=reject; adkim=s; aspf=r`
in their DMARC, the private zones only `p=reject`. Matching them would mean
loosening the business domains, not tidying them.

Four properties of the API shape the file:

- **Records with `meta.read_only` do not belong here.** Email Routing owns the
  apex MX and the `cf2024-1._domainkey` of seb-it.com, and the API answers
  every write to them with `This record is managed by Email Routing (1046)`.
  They are filtered out rather than listed, so enabling Email Routing on
  another zone does not reintroduce the problem.
- **`name` is relative for subdomains, absolute for the apex.** The provider
  stores `mail`, not `mail.seb-it.com`, and a full name forces replacement.
  Terraform then destroys and recreates the MX records of a zone, which is a
  gap in mail delivery, not a no-op.
- **`ttl` and `comment` come from the existing records, not from a
  convention.** The zones mix TTL 1 and 3600 and some records already carry a
  comment. Normalising them would touch 23 records for no reason and bury the
  one change that matters in the noise.
- **TXT values carry their own quotes.** Cloudflare accepts both forms and
  resolves them identically, but it stores what it is given, and the dashboard
  flags an unquoted value. Quoted keeps every record in a zone looking the
  same. Careful when reading them back: the API splits anything over 255
  characters into several quoted strings, so stripping only the outer pair
  leaves a `" "` sitting in the middle of a long DKIM key.

No zone carries a `*._domainkey` with an empty `p=`. To a verifier a revoked
wildcard key and a missing record are the same PERMFAIL (RFC 6376 §6.1.2), and
the wildcard answers for every selector without a record of its own, which
hides whether a selector exists at all.

Checking a record after an apply: ask an authoritative nameserver, not
`1.1.1.1`. The resolver caches the old TXT for up to five minutes and makes a
correct change look like it did not happen.
