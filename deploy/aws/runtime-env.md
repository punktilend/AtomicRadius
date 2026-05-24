# Atomic Radius AWS Runtime Environment Map

This file tracks production runtime variables needed before ECS services are scaled above zero.

Do not put real secret values in this file. Store secrets in AWS Secrets Manager or SSM `SecureString`.

## Non-Secret Core Values

These can live in task definition `Environment` entries or SSM `String` parameters:

- `NODE_ENV=production`
- `AWS_REGION=us-east-1`
- `FLUXER_API_PORT=8080`
- `FLUXER_GATEWAY_WS_PORT=8080`
- `FLUXER_GATEWAY_RPC_PORT=8081`
- `FLUXER_MEDIA_PROXY_PORT=8080`
- `FLUXER_ADMIN_PORT=8080`
- `FLUXER_MARKETING_PORT=8080`
- `FLUXER_PATH_GATEWAY=/gateway`
- `FLUXER_PATH_ADMIN=/admin`
- `FLUXER_PATH_MARKETING=/marketing`
- `METRICS_MODE=noop`
- `EMAIL_ENABLED=false`
- `SMS_ENABLED=false`
- `CAPTCHA_ENABLED=false`
- `SEARCH_ENABLED=false`
- `STRIPE_ENABLED=false`
- `VOICE_ENABLED=false`
- `CLAMAV_ENABLED=false`
- `CLOUDFLARE_PURGE_ENABLED=false`
- `SELF_HOSTED=true`
- `RELEASE_CHANNEL=stable`

## Domain Values

Decide final AWS/canary hostnames before enabling public services:

- `FLUXER_APP_ENDPOINT`
- `FLUXER_API_PUBLIC_ENDPOINT`
- `FLUXER_API_CLIENT_ENDPOINT`
- `FLUXER_GATEWAY_ENDPOINT`
- `FLUXER_MEDIA_ENDPOINT`
- `FLUXER_CDN_ENDPOINT`
- `FLUXER_MARKETING_ENDPOINT`
- `FLUXER_ADMIN_ENDPOINT`
- `FLUXER_INVITE_ENDPOINT`
- `FLUXER_GIFT_ENDPOINT`
- `ADMIN_OAUTH2_REDIRECT_URI`
- `PASSKEY_RP_ID`
- `PASSKEY_ALLOWED_ORIGINS`
- `FLUXER_COOKIE_DOMAIN`

## AWS Object Storage Values

Current AWS buckets:

- `AWS_S3_BUCKET_CDN=atomic-radius-prod-static-817378414866-us-east-1`
- `AWS_S3_BUCKET_STATIC=atomic-radius-prod-static-817378414866-us-east-1`
- `AWS_S3_BUCKET_UPLOADS=atomic-radius-prod-uploads-817378414866-us-east-1`
- `AWS_S3_BUCKET_REPORTS=atomic-radius-prod-reports-817378414866-us-east-1`
- `AWS_S3_BUCKET_HARVESTS=atomic-radius-prod-harvests-817378414866-us-east-1`
- `AWS_S3_BUCKET_DOWNLOADS=atomic-radius-prod-downloads-817378414866-us-east-1`

For native AWS S3, prefer IAM task roles over static keys. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_S3_ENDPOINT` are only needed for S3-compatible providers such as MinIO, Backblaze, or OVH.

## Data-Service Values

Not ready until data services exist:

- `DATABASE_URL`
- `REDIS_URL`
- `CASSANDRA_HOSTS`
- `CASSANDRA_KEYSPACE`
- `CASSANDRA_LOCAL_DC`
- `CASSANDRA_USERNAME`
- `CASSANDRA_PASSWORD`
- `MEILISEARCH_URL`
- `MEILISEARCH_API_KEY`
- `CLICKHOUSE_URL`
- `CLICKHOUSE_DATABASE`
- `CLICKHOUSE_USER`
- `CLICKHOUSE_PASSWORD`

`data-services.yaml` is staged for RDS PostgreSQL and ElastiCache Valkey. After that stack is applied, run `sync-data-runtime.ps1` to write `DATABASE_URL` and `REDIS_URL` to SSM `SecureString`.

`scylla-ec2.yaml` is staged for a single-node ScyllaDB layer. After that stack is applied, run `sync-scylla-runtime.ps1` to write Cassandra config and password values to SSM.

`task-definitions.yaml` reads `DATABASE_URL`, `REDIS_URL`, and Cassandra settings from SSM. Run `check-runtime-ready.ps1` before promoting new API task definitions or scaling services above zero.

`sync-external-cassandra-runtime.ps1` can store temporary external Cassandra settings in SSM if Scylla-on-EC2 remains blocked.

## Secrets

Generated and stored in SSM `SecureString` under `/atomic-radius/prod/secrets`:

- `SECRET_KEY_BASE`
- `SUDO_MODE_SECRET`
- `GATEWAY_RPC_SECRET`
- `GATEWAY_ADMIN_SECRET`
- `ERLANG_COOKIE`
- `MEDIA_PROXY_SECRET_KEY`

Still pending third-party/service secrets:

- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `ADMIN_OAUTH2_CLIENT_SECRET`
- `SENDGRID_API_KEY`
- `SENDGRID_WEBHOOK_PUBLIC_KEY`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_VERIFY_SERVICE_SID`
- `HCAPTCHA_SECRET_KEY`
- `TURNSTILE_SECRET_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `CLOUDFLARE_API_TOKEN`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `TENOR_API_KEY`
- `YOUTUBE_API_KEY`
- `ALERT_WEBHOOK_URL`

## Before Scaling ECS Services

1. Push images to ECR using `.github/workflows/aws-build-push.yaml` or local Docker.
2. Resolve AWS account verification so EC2 instances can launch.
3. Scale `atomic-radius-prod-ecs` to at least one instance.
4. Provision or connect Postgres, Redis, and Cassandra/Scylla.
5. Load data-service and third-party secrets into SSM `SecureString`.
6. Run `check-runtime-ready.ps1`.
7. Promote the intended image tag with `promote-image-tag.ps1`.
8. Add ALB/listeners/target groups for public services.
9. Scale services from `0` to canary counts with `scale-ecs-services.ps1 -Apply`.

Use `get-deployment-status.ps1` before and after scaling to check stack state, ECS service counts, EC2 capacity, and missing runtime parameters.
Use `test-public-endpoints.ps1` after ALB/DNS routing exists to smoke-test the public canary routes.

If EC2 remains blocked, use the zero-count Fargate fallback services and `scale-fargate-services.ps1`. Fargate can run the app containers, but Cassandra/Scylla still needs either EC2, temporary RackNerd connectivity, or a managed/external replacement.

`edge-alb.yaml` is staged for public HTTP/HTTPS routing and target groups. After that stack is applied, run `attach-edge-target-groups.ps1 -Apply` before scaling public ECS services.

`cloudfront-static.yaml` is staged for static S3 delivery through CloudFront with Origin Access Control.

`dns-zone.yaml` and `acm-certificates.yaml` are staged for `atomicradius.app` Route 53 and ACM setup. After applying them and syncing DNS runtime parameters, ALB and CloudFront deploy scripts can pick up the certificate ARN automatically.
