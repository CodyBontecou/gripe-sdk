# Pre-prod TODO

The MVP is **single-tenant**: one deploy = one project. It trusts a static
API key, uses a single PAT, and posts to a single repo. To run this in
front of more than one user, work through the lists below.

## Auth & multi-tenancy
- [ ] Add D1 binding; create `tenants` and `apps` tables.
  - `apps`: `id`, `tenant_id`, `name`, `api_key_hash`, `github_repo`,
    `github_token_encrypted`, `default_labels`, `created_at`.
- [ ] Replace `GRIPE_API_KEY` env check with hashed-key lookup in `apps`.
- [ ] Encrypt GitHub tokens at rest (Workers Crypto + master key in env).
- [ ] Migrate from PAT to GitHub App.
  - [ ] Register the Gripe GitHub App.
  - [ ] OAuth callback that records `installation_id` per app.
  - [ ] Replace `GITHUB_TOKEN` usage with installation-token minting
    (sign JWT with private key, exchange for installation token, cache).
- [ ] Per-app rate limiting (Cloudflare Rate Limiting binding or D1 counter).

## Onboarding UI
- [ ] Dashboard at `gripe.dev`: sign in with GitHub, create app, install
  GitHub App on a repo, copy API key.
- [ ] Per-app settings: default labels, assignees, issue title prefix,
  issue template.

## Reliability
- [ ] Retry GitHub API calls on 5xx (capped exponential backoff).
- [ ] Persist failed reports in a D1 dead-letter queue and surface in dashboard.
- [ ] Validate image: max size (e.g. 5 MB), real PNG magic bytes,
  dimensions cap.
- [ ] Validate metadata against a `zod` schema; reject malformed payloads
  with a structured error.
- [ ] Strip EXIF / metadata from the image before storing.

## Image storage
- [ ] Replace `R2_PUBLIC_BASE = *.r2.dev` with a custom domain
  (e.g. `images.gripe.dev`) configured at the R2 bucket level.
- [ ] R2 lifecycle rule: delete reports older than N days for free tier;
  keep forever for paid.
- [ ] Optional bring-your-own-bucket (point an app at the tenant's own R2/S3).

## Observability
- [ ] Logpush → R2 / Datadog / wherever.
- [ ] Per-tenant metrics: reports/day, GitHub error rate, p95 latency.
- [ ] Sentry (or equivalent) for exceptions.

## SDK ↔ backend
- [ ] Lock the `/v1/reports` schema and version anything that breaks.
- [ ] Return enough info on failure for the SDK to retry meaningfully
  (e.g. `429` with `Retry-After`).
- [ ] Consider presigned-upload flow: SDK uploads PNG straight to R2 and
  POSTs only the metadata + key to the API (avoids large multipart
  bodies hitting the Worker).

## Abuse / safety
- [ ] Don't echo `metadata` or `comment` to logs (may contain user PII).
- [ ] Reject browser origins explicitly (CORS off, return 403 if Origin
  header looks browser-y) — only iOS clients should be hitting this.
- [ ] Add Cloudflare Turnstile or similar if any public unauthenticated
  endpoint is added later.
- [ ] Audit: confirm submitted images can't deanonymize end users
  (screenshots may include other apps' content via screen-sharing UIs).

## Tests
- [ ] Integration test using `unstable_dev` from wrangler — POST a fake
  report, assert R2 was written and a mocked GitHub got called.
- [ ] Property tests for `renderIssueBody` against weird inputs
  (markdown injection in `comment`, broken metadata, very long strings).
- [ ] Light load test (k6, autocannon) — 100 RPS for 1 min, watch p95.

## Deployment
- [ ] `wrangler secret put GRIPE_API_KEY GITHUB_TOKEN` for production.
- [ ] Bind a custom domain on the Workers route.
- [ ] Verify the R2 bucket exists and that `R2_PUBLIC_BASE` resolves
  publicly to its objects.
- [ ] CI smoke test that hits `/health` after every deploy.
- [ ] Backup/runbook: how to rotate `GRIPE_API_KEY` and `GITHUB_TOKEN`
  without dropping in-flight reports.
