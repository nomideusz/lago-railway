# Deploy and Host Lago on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/lago-production?utm_medium=integration&utm_source=button&utm_campaign=lago-production)

[Lago](https://www.getlago.com/) is the open-source billing engine for usage-based, subscription and hybrid pricing. It is an alternative to Stripe Billing, Chargebee and Orb. You send usage events to its API, and Lago meters them and applies your plans, coupons, credits and taxes. It then issues invoices with PDFs and pushes them to Stripe, Adyen or GoCardless for payment. This template runs the complete Lago v1.54.0 stack, including the background worker and scheduler that do the actual billing.

## About Hosting Lago

The stack is five services: Lago, API, PDF, Postgres and Redis.

- **Lago** is the dashboard (upstream's `lago-front` image) on its own public domain. This is where you sign in and set up plans, customers and invoices.
- **API** runs Lago's Rails API, Sidekiq worker and billing clock in one container. Its public domain is the REST and GraphQL endpoint your app sends events to. **The worker and clock are what generate invoices.** The clock enqueues billing, invoice finalization, overdue and wallet jobs every hour, and the worker runs them along with webhooks and PDF rendering. Lago templates that run only the API and dashboard accept events but never bill anyone. Upstream runs these three processes as separate containers that share a storage volume. Railway volumes can't be shared between services, so here they run in one container, and if any of them stops, Railway restarts the container.
- **PDF** is Lago's Gotenberg build, which renders invoice and credit note PDFs on the private network.
- **Postgres 17 with pg_partman**: Lago's schema loads the `pg_partman` extension on the first migration, so a stock Postgres fails the first boot. Upstream's own partman image is PostgreSQL 15.0.
- **Redis 8** holds the job queues, with append-only persistence and no eviction so that queued billing jobs survive a restart.
- **Locked to you.** Your admin account is created on the first boot and public sign-up is closed. Integration credentials are encrypted with keys generated for this deploy.
- **Its own signing key.** Lago signs sessions and webhooks with an RSA key. Other templates ship one fixed key that is visible in the template itself. This one generates a key on the first boot and stores it on the API's volume, so webhook signatures stay valid across redeploys.

## Common Use Cases

- Usage-based or hybrid pricing for a SaaS or API product: per-seat, per-call, per-token or per-GB charges, prepaid credits and minimum commitments
- Replacing Stripe Billing or Chargebee to stop paying a percentage of revenue, while still collecting payments through Stripe, Adyen or GoCardless
- Keeping billing data and invoices on infrastructure you control, with a REST API and signed webhooks for your own app to use

## Dependencies for Lago Hosting

- Postgres 17 with pg_partman (included, private network only)
- Redis 8 (included, private network only)
- Gotenberg for PDFs (included, private network only)
- Optional: a Stripe, Adyen or GoCardless account to collect payments, and SMTP credentials to email invoices

### Deployment Dependencies

- [Lago self-hosting docs](https://getlago.com/docs/guide/self-hosted/docker)
- [Lago environment variables](https://getlago.com/docs/guide/self-hosted/docker#environment-variables)
- [Lago API reference](https://getlago.com/docs/api-reference/intro)
- [Lago on GitHub](https://github.com/getlago/lago)
- [Template source on GitHub](https://github.com/nomideusz/lago-railway)

### Implementation Details

**The dashboard is at the Lago service's Railway domain, and the API is at the API service's domain.** At deploy time, enter your company name, which appears as the sender on invoices, and your admin email. The first boot loads the database schema and takes about a minute.

1. Open the **Lago** service's domain and sign in with your admin email. The password is `LAGO_ORG_USER_PASSWORD` in the **API** service's Variables tab.
2. Get your API key from **Developers → API keys & ID**. Send requests to `https://<API domain>/api/v1/...`.
3. To receive webhooks, add an endpoint under **Developers → Webhooks**. Lago signs them with this deployment's key, and the public key is at `GET /api/v1/webhooks/public_key`.
4. Connect payment providers under **Settings → Integrations**.

**Invoice emails** need SMTP: fill in `LAGO_FROM_EMAIL` and the `LAGO_SMTP_*` variables on the API service. Railway allows outbound SMTP only on the Pro plan and above. On Hobby, leave them empty and send invoices from your own app through webhooks, or download the PDFs from the dashboard.

**Teammates.** Sign-up is closed, so invite people from **Settings → Members**. To reopen sign-up, set `LAGO_DISABLE_SIGNUP` to `false`.

**Memory.** Expect about 950 MB at idle: about 840 MB for the API container (three Ruby processes), 75 MB for Postgres, and a few MB each for the dashboard, PDF and Redis. That is over the Trial plan's limit, so deploy on Hobby or above.

**Custom domains.** Add them under each service's Settings → Networking. Then update `LAGO_API_URL` and `LAGO_FRONT_URL` on the API service and `API_URL` on the Lago service.

**Never change** `LAGO_ENCRYPTION_*` or `SECRET_KEY_BASE` after the first boot. They encrypt stored integration credentials. To bring your own RSA key, set `LAGO_RSA_PRIVATE_KEY` (base64 PEM) on the API service; otherwise the generated one at `/data/rsa_private.pem` is used.

**Backups.** Turn on Railway's volume backups for Postgres (all billing data) and for the API volume, which holds the invoice PDFs and the signing key.

## Why Deploy Lago on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Lago on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
