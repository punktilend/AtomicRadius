# Atomic Radius AWS Migration Runbook

This runbook tracks the migration from the current RackNerd VPS plus S3-compatible object storage setup into AWS.

## Credential Model

Do not paste AWS access keys into chat, commits, GitHub issues, or documentation.

The local machine is already authenticated with AWS CLI:

- Account: `817378414866`
- Principal: `arn:aws:iam::817378414866:user/adam-admin`
- Default region: `us-east-1`

Preferred operating model:

1. Use local AWS CLI profiles for interactive work.
2. Use IAM roles for ECS tasks and automation.
3. Store application secrets in AWS Secrets Manager or SSM Parameter Store.
4. Store GitHub deployment credentials as GitHub Actions secrets or use GitHub OIDC with an AWS deploy role.

If credentials need to be set up on another machine, use one of these options:

- AWS IAM Identity Center / SSO profile, preferred for humans.
- A short-lived role session.
- As a fallback only, an IAM access key configured locally with `aws configure --profile atomic-radius-migration`.

Never commit `.env`, `fluxer.env`, AWS key files, PEM files, database dumps, or bucket sync credentials.

## Current Workload Map

The repo currently contains these deployment-relevant services:

- Public/runtime services: `api`, `worker`, `gateway`, `media`, `admin`, `marketing`, `docs`
- Edge/proxy: Caddy/Nginx style routing
- Storage/data: Postgres, Cassandra or Scylla, Valkey/Redis, MinIO/S3-compatible buckets
- Optional/supporting services: ClamAV, Meilisearch, ClickHouse metrics, LiveKit
- CI/CD: GitHub Actions currently builds Docker images and deploys over SSH to a server

## AWS Target Map

Recommended first migration target:

- DNS: Route 53
- TLS: ACM
- HTTP ingress: ALB
- CDN/static/media: CloudFront
- Object storage: S3
- Container images: ECR
- Compute: ECS on Fargate or ECS on EC2
- Postgres: RDS PostgreSQL
- Redis/Valkey: ElastiCache
- Cassandra/Scylla: self-managed Scylla or Cassandra on EC2 first
- Meilisearch: ECS/EC2 with persistent EBS/EFS storage
- ClickHouse: EC2 or external ClickHouse Cloud later
- Secrets/config: Secrets Manager or SSM Parameter Store
- Logs: CloudWatch Logs
- Metrics/alarms: CloudWatch, plus existing Atomic Radius metrics service as needed

## Migration Phases

### Phase 0: Inventory

- Export current RackNerd container/service list.
- Record current domains, ports, TLS routing, and DNS providers.
- Record current bucket names, object counts, total storage size, and public/private access model.
- Record current database sizes for Postgres and Cassandra/Scylla.
- Record required environment variables and classify each as public config, secret, or generated runtime value.

### Phase 1: AWS Foundation

- Create an Atomic Radius VPC with public and private subnets across at least two Availability Zones.
- Create security groups for ALB, ECS tasks, databases, cache, and admin SSH/bastion access if needed.
- Create ECR repositories for each container image.
- Create S3 buckets for static, uploads, reports, harvests, and downloads.
- Create Secrets Manager or SSM paths for production and canary environments.
- Create IAM roles for ECS tasks and GitHub deployment.

### Phase 2: Data Services

- Provision RDS PostgreSQL.
- Provision ElastiCache Valkey/Redis.
- Provision Scylla/Cassandra on EC2 with EBS volumes, or validate Amazon Keyspaces compatibility before choosing Keyspaces.
- Provision Meilisearch persistence if production search is required.
- Decide whether ClickHouse metrics migrates now or remains optional/noop during first cutover.

### Phase 3: Object Storage Migration

- Sync existing S3-compatible buckets into AWS S3.
- Preserve object keys and content types.
- Configure bucket CORS and lifecycle policies.
- Put CloudFront in front of public static/media delivery.
- Update app env vars for S3 bucket names, S3 endpoint behavior, and CDN/media endpoints.

### Phase 4: Runtime Deployment

- Convert existing Docker/Swarm deployment to ECS task definitions and services.
- Push images to ECR from GitHub Actions.
- Deploy canary stack first.
- Wire service discovery or internal DNS for API, gateway, media proxy, metrics, and supporting services.
- Attach ALB routes for public services.

### Phase 5: Verification

- Verify API health checks.
- Verify login/session flows.
- Verify websocket gateway connectivity.
- Verify uploads, reads, deletes, and media proxy behavior against S3.
- Verify worker jobs.
- Verify admin, marketing, docs, and static delivery.
- Verify email/SMS/payment/captcha/webhook integrations in production-like canary.
- Run integration tests against canary where practical.

### Phase 6: Cutover

- Lower DNS TTL ahead of cutover.
- Freeze writes briefly if needed for final data sync.
- Perform final object/database syncs.
- Point canary domains to AWS first.
- Point production domains to AWS after smoke tests pass.
- Keep RackNerd and old object storage available for rollback during the agreed window.

### Phase 7: Decommission

- Disable old GitHub SSH deploy paths.
- Revoke old provider credentials.
- Archive final database/object backups.
- Remove RackNerd services after rollback window.
- Remove old bucket access after confirming all objects are served from AWS.

## First Decisions Needed

1. Use ECS Fargate for simplicity, or ECS on EC2 for lower cost and more control?
2. Keep Cassandra/Scylla self-managed on EC2 for the first migration, or spend time validating Amazon Keyspaces?
3. Migrate LiveKit to AWS in this pass, or keep voice separate until API/media/gateway are stable?
4. Use Route 53 for DNS cutover, or leave DNS hosted elsewhere and point records at AWS?

## Immediate Next Step

Create a non-destructive AWS inventory and cost-shape estimate, then scaffold infrastructure as code for the foundation resources.

## Foundation Stack Status

The `atomic-radius-foundation` CloudFormation stack was created in `us-east-1` on May 12, 2026.

Created resources:

- VPC: `vpc-0b91aa2d4d4af2447`
- Public subnets: `subnet-0bcb42114323b56d4`, `subnet-00cfe2fc608866089`
- Private subnets: `subnet-068d05fc7982a34f5`, `subnet-0b66b3a3ad8b8bd69`
- ALB security group: `sg-086a8d546074c6b82`
- ECS service security group: `sg-02e1d2f4c39d1958f`
- Data security group: `sg-0520e64644836ca57`
- ECS task execution role: `arn:aws:iam::817378414866:role/atomic-radius-prod-ecs-task-execution`
- ECS task role: `arn:aws:iam::817378414866:role/atomic-radius-prod-ecs-task`

Created S3 buckets:

- `atomic-radius-prod-static-817378414866-us-east-1`
- `atomic-radius-prod-uploads-817378414866-us-east-1`
- `atomic-radius-prod-reports-817378414866-us-east-1`
- `atomic-radius-prod-harvests-817378414866-us-east-1`
- `atomic-radius-prod-downloads-817378414866-us-east-1`

Created ECR repositories:

- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-api`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-api-worker`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-gateway`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-media-proxy`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-admin`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-marketing`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-docs`
- `817378414866.dkr.ecr.us-east-1.amazonaws.com/atomic-radius-metrics`

No ECS clusters, RDS instances, ElastiCache clusters, NAT gateways, load balancers, EC2 instances, or Route 53 zones were created in this first foundation step.

## ECS-on-EC2 Compute Stack Status

The `atomic-radius-compute-ecs-ec2` CloudFormation stack was created in `us-east-1` on May 12, 2026.

Created resources:

- ECS cluster: `atomic-radius-prod`
- ECS cluster ARN: `arn:aws:ecs:us-east-1:817378414866:cluster/atomic-radius-prod`
- Capacity provider: `atomic-radius-prod-ec2`
- Auto Scaling Group: `atomic-radius-prod-ecs`
- ECS instance role: `arn:aws:iam::817378414866:role/atomic-radius-prod-ecs-instance`

Current capacity:

- Minimum instances: `0`
- Desired instances: `0`
- Maximum instances: `3`
- Registered ECS container instances: `0`

The first attempts to launch one `t3.medium` ECS instance failed because AWS returned:

> This account is currently blocked and not recognized as a valid account.

After a payment card was added and set as default, an EC2 dry-run returned `DryRunOperation`, but the Auto Scaling Group still failed to launch real ECS hosts on May 13, 2026 and May 18, 2026 with the same account-verification block. The ASG was returned to zero desired capacity after each failed attempt.

AWS account verification for EC2 was cleared by May 22, 2026. Auto Scaling successfully launched:

- Instance ID: `i-0c11808594efe3358`
- Instance type: `t3.medium`
- Private IP: `10.42.11.13`

The ECS agent initially did not register because user data started `ecs.service` synchronously during `cloud-final`, while the service itself waits for `cloud-final`. The launch template was patched to use `systemctl start --no-block ecs`, and the compute stack was updated while preserving `min=1`, `desired=1`.

Current capacity:

- Minimum instances: `1`
- Desired instances: `1`
- Maximum instances: `3`
- Registered ECS container instances: `1`

ECS capacity-provider managed scaling is currently disabled to prevent accidental EC2 launches while the stack is staged at zero capacity. Re-enable it later if you want ECS to control ASG capacity automatically.

## GitHub OIDC Status

The `atomic-radius-github-oidc` CloudFormation stack was created in `us-east-1` on May 12, 2026.

Created resources:

- OIDC provider: `arn:aws:iam::817378414866:oidc-provider/token.actions.githubusercontent.com`
- GitHub deploy role: `arn:aws:iam::817378414866:role/atomic-radius-prod-github-deploy`

The role currently trusts GitHub Actions runs from:

- `repo:punktilend/AtomicRadius:ref:refs/heads/main`
- `repo:punktilend/AtomicRadius:ref:refs/heads/canary`

It can push images to `atomic-radius-*` ECR repositories and perform limited ECS/CloudFormation deployment reads and updates.

## Runtime Parameter Status

Non-secret deployment parameters were synced to SSM Parameter Store under `/atomic-radius/prod`.

Examples:

- `/atomic-radius/prod/aws/region`
- `/atomic-radius/prod/network/vpc_id`
- `/atomic-radius/prod/network/public_subnet_ids`
- `/atomic-radius/prod/network/private_subnet_ids`
- `/atomic-radius/prod/s3/static_bucket`
- `/atomic-radius/prod/s3/uploads_bucket`
- `/atomic-radius/prod/ecr/api_repository_uri`
- `/atomic-radius/prod/ecr/gateway_repository_uri`
- `/atomic-radius/prod/ecr/media_proxy_repository_uri`

Secrets are intentionally not stored yet. Use Secrets Manager or SSM `SecureString` for real production secrets once the final runtime env map is reviewed.

Internal generated secrets are now stored as SSM `SecureString` values under `/atomic-radius/prod/secrets`:

- `/atomic-radius/prod/secrets/secret_key_base`
- `/atomic-radius/prod/secrets/sudo_mode_secret`
- `/atomic-radius/prod/secrets/gateway_rpc_secret`
- `/atomic-radius/prod/secrets/gateway_admin_secret`
- `/atomic-radius/prod/secrets/erlang_cookie`
- `/atomic-radius/prod/secrets/media_proxy_secret_key`

Non-secret app runtime config is stored under `/atomic-radius/prod/config`, including endpoints, ports, feature flags, and S3 bucket env vars.

Third-party secrets are not stored yet. Add those later as `SecureString` values when enabling email, SMS, CAPTCHA, Stripe, Cloudflare purge, LiveKit, Tenor, or YouTube.

## Task Definition Status

The `atomic-radius-task-definitions` CloudFormation stack was created in `us-east-1` on May 12, 2026.

Registered ECS task definitions:

- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-api:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-api-worker:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-gateway:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-media-proxy:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-admin:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-marketing:3`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-docs:2`
- `arn:aws:ecs:us-east-1:817378414866:task-definition/atomic-radius-prod-metrics:3`

These task definitions do not start containers by themselves. They currently use the `main` image tag. The app/service task definitions now pull key config and internal secrets from SSM. Revision 3 task definitions, and docs revision 2, are compatible with both ECS-on-EC2 and Fargate.

The next task-definition revision is prepared to inject:

- `/atomic-radius/prod/secrets/database_url`
- `/atomic-radius/prod/secrets/redis_url`
- `/atomic-radius/prod/config/CASSANDRA_HOSTS`
- `/atomic-radius/prod/config/CASSANDRA_KEYSPACE`
- `/atomic-radius/prod/config/CASSANDRA_LOCAL_DC`
- `/atomic-radius/prod/config/CASSANDRA_USERNAME`
- `/atomic-radius/prod/secrets/cassandra_password`

Do not promote a new task-definition revision for runnable API services until `check-runtime-ready.ps1` passes.

## Zero-Count ECS Service Status

The `atomic-radius-ecs-services-zero` CloudFormation stack was created in `us-east-1` on May 12, 2026.

Created ECS services:

- `atomic-radius-prod-api`
- `atomic-radius-prod-api-worker`
- `atomic-radius-prod-gateway`
- `atomic-radius-prod-media-proxy`
- `atomic-radius-prod-admin`
- `atomic-radius-prod-marketing`
- `atomic-radius-prod-docs`
- `atomic-radius-prod-metrics`

All services are currently:

- Status: `ACTIVE`
- Desired count: `0`
- Running count: `0`

They are attached to the `atomic-radius-prod-ec2` capacity provider and private subnets. No containers will start until desired counts are raised and EC2 capacity is available.

Use `update-services-to-latest-taskdefs.ps1` after registering new task-definition revisions so the zero-count ECS services point at the latest revision before scaling up.

Use `get-deployment-status.ps1` for a one-command snapshot of CloudFormation stacks, ECS service counts, EC2 capacity, and runtime SSM readiness.

Use `scale-ecs-services.ps1` to set ECS desired counts when the account is ready to launch compute. It is a dry run by default and requires `-Apply` to change service counts. It also runs the runtime readiness check before starting API, worker, gateway, or media proxy tasks unless `-SkipRuntimeCheck` is passed.

Use `test-public-endpoints.ps1` after ALB/DNS routing exists to smoke-test public endpoints. It checks API, media, and metrics health endpoints plus admin, marketing, and docs root pages. Endpoints can come from SSM config or explicit script arguments.

## Zero-Count Fargate Fallback Status

The `atomic-radius-ecs-services-fargate-zero` CloudFormation stack was created in `us-east-1` on May 19, 2026.

Created Fargate fallback ECS services:

- `atomic-radius-prod-fargate-api`
- `atomic-radius-prod-fargate-api-worker`
- `atomic-radius-prod-fargate-gateway`
- `atomic-radius-prod-fargate-media-proxy`
- `atomic-radius-prod-fargate-admin`
- `atomic-radius-prod-fargate-marketing`
- `atomic-radius-prod-fargate-docs`
- `atomic-radius-prod-fargate-metrics`

All Fargate fallback services are currently desired count `0`. They use public subnets with assigned public IPs so Fargate can pull from ECR without NAT gateways or VPC endpoints. They still only allow inbound service traffic from the ALB security group.

Use `scale-fargate-services.ps1` to scale the fallback services. It defaults to dry-run and runs the same runtime readiness check before starting API, worker, gateway, or media proxy tasks.

## AWS-Native S3 Credential Readiness

The API and media proxy now allow native AWS S3 credentials from the ECS task role credential chain.

For AWS S3:

- Leave `AWS_S3_ENDPOINT` unset.
- Leave `AWS_ACCESS_KEY_ID` unset.
- Leave `AWS_SECRET_ACCESS_KEY` unset.
- Set the bucket variables to the AWS bucket names.

For S3-compatible providers:

- Set `AWS_S3_ENDPOINT`.
- Set `AWS_ACCESS_KEY_ID`.
- Set `AWS_SECRET_ACCESS_KEY`.

## Object Storage Migration Readiness

Backblaze B2 to AWS S3 migration tooling is staged:

- Bucket map: `object-storage-map.json`
- Non-secret environment template: `object-storage.env.example`
- Inventory/compare script: `measure-object-storage.ps1`
- Transfer script: `sync-object-storage.ps1`

The scripts expect Backblaze credentials and source bucket names in environment variables:

- `B2_ENDPOINT_URL`
- `B2_REGION`
- `B2_KEY_ID`
- `B2_APPLICATION_KEY`
- `B2_STATIC_BUCKET`
- `B2_UPLOADS_BUCKET`
- `B2_REPORTS_BUCKET`
- `B2_HARVESTS_BUCKET`
- `B2_DOWNLOADS_BUCKET`

`sync-object-storage.ps1` uses `rclone` for direct S3-compatible to AWS S3 sync. It defaults to dry-run. Add `-Apply` only when ready to copy objects.

Recommended object migration flow:

1. Export the Backblaze environment variables locally. Do not commit them.
2. Run `measure-object-storage.ps1` to record source and target object counts/bytes.
3. Run `sync-object-storage.ps1` without `-Apply` and review the planned copy/delete operations.
4. Run `sync-object-storage.ps1 -Apply` for the first full copy.
5. Run `measure-object-storage.ps1` again and compare deltas.
6. Before cutover, briefly freeze writes or schedule a maintenance window.
7. Run `sync-object-storage.ps1 -Apply` again for the final delta copy.
8. Keep Backblaze credentials and buckets active until AWS media reads are verified.

## Managed Data Services Readiness

The managed data-service template is staged but not applied:

- Template: `data-services.yaml`
- Guarded deploy script: `deploy-data-services.ps1`
- Runtime sync script: `sync-data-runtime.ps1`

The `atomic-radius-data-services` CloudFormation stack was created in `us-east-1` on May 19, 2026.

Created billable resources:

- RDS PostgreSQL with AWS-managed master password
- ElastiCache Valkey with generated auth token
- Private subnet groups using the Atomic Radius VPC
- Data security group access from ECS services

The first create attempt failed because the generated Valkey token included characters rejected by ElastiCache. The template was corrected to generate an alphanumeric token, and the stack was recreated successfully.

`sync-data-runtime.ps1` stored these SSM `SecureString` values:

- `/atomic-radius/prod/secrets/database_url`
- `/atomic-radius/prod/secrets/redis_url`

Use `migrate-postgres-to-rds.ps1` to move the current RackNerd/Postgres database into RDS. It expects `SOURCE_DATABASE_URL` in the environment and reads the target RDS `database_url` from SSM.

Cassandra/Scylla is still pending as a separate stateful layer.

## Scylla/Cassandra Readiness

The self-managed ScyllaDB-on-EC2 template has been applied:

- Template: `scylla-ec2.yaml`
- Guarded deploy script: `deploy-scylla-ec2.ps1`
- Runtime sync script: `sync-scylla-runtime.ps1`

The `atomic-radius-scylla-ec2` CloudFormation stack was created in `us-east-1` on May 22, 2026.

Created billable resources:

- One private EC2 instance running ScyllaDB in Docker
- Encrypted root and data EBS volumes
- SSM access for instance administration
- A generated Scylla application password in Secrets Manager
- Keyspace bootstrap for `atomic_radius`
- ECS-to-Scylla private security-group access

Current Scylla details:

- Instance ID: `i-0a9b09015879dbe33`
- Private IP: `10.42.130.45`
- Cassandra hosts: `10.42.130.45`
- Cassandra keyspace: `atomic_radius`
- Cassandra username: `atomic_radius`
- Cassandra local datacenter: `dc1`

`sync-scylla-runtime.ps1` stored:

- `/atomic-radius/prod/config/CASSANDRA_HOSTS`
- `/atomic-radius/prod/config/CASSANDRA_KEYSPACE`
- `/atomic-radius/prod/config/CASSANDRA_LOCAL_DC`
- `/atomic-radius/prod/config/CASSANDRA_USERNAME`
- `/atomic-radius/prod/secrets/cassandra_password`

`check-runtime-ready.ps1` now passes.

If EC2 remains blocked and Cassandra must temporarily stay outside AWS, use `sync-external-cassandra-runtime.ps1` to store external Cassandra connection values in SSM. It expects:

- `CASSANDRA_HOSTS`
- `CASSANDRA_KEYSPACE`
- `CASSANDRA_LOCAL_DC`
- `CASSANDRA_USERNAME`
- `CASSANDRA_PASSWORD`

This is a bridge option for Fargate canary testing. The external Cassandra host must allow inbound client traffic from AWS task egress.

## Edge and CDN Readiness

The ALB edge template is staged but not applied:

- Template: `edge-alb.yaml`
- Guarded deploy script: `deploy-edge-alb.ps1`
- ECS attach script: `attach-edge-target-groups.ps1`

The `atomic-radius-edge-alb` CloudFormation stack was created in `us-east-1` on May 19, 2026.

Created billable ALB resources:

- Internet-facing Application Load Balancer
- Target groups for API, gateway, media proxy, admin, marketing, docs, and metrics
- Path rules matching the local Caddy routing shape
- Optional ACM certificate support for HTTPS

Current ALB DNS name:

- `atomic-radius-prod-499602146.us-east-1.elb.amazonaws.com`

The Fargate fallback services are attached to ALB target groups at desired count `0` using `attach-edge-target-groups.ps1 -Fargate -Apply`.

The static CDN template is staged but not applied:

- Template: `cloudfront-static.yaml`
- Guarded deploy script: `deploy-cloudfront-static.ps1`

The template prepares billable CloudFront resources:

- CloudFront distribution for the Atomic Radius static S3 bucket
- S3 Origin Access Control
- Static bucket policy allowing CloudFront read access
- Optional custom CDN domain and ACM certificate support

`deploy-cloudfront-static.ps1 -Apply` was attempted on May 19, 2026 and again on May 22, 2026. AWS rejected CloudFront distribution creation with:

> Your account must be verified before you can add new CloudFront resources.

The rolled-back CloudFront stack was deleted both times. CloudFront remains blocked by AWS account verification.

## CI Readiness

GitHub Actions now includes `aws-infra-validate.yaml`, which validates all `deploy/aws/*.yaml` CloudFormation templates using the Atomic Radius GitHub OIDC role on `main`, `canary`, or manual runs.

GitHub Actions also includes `aws-promote-taskdefs.yaml`, a manual promotion workflow that:

- Registers a chosen ECR image tag into the ECS task definitions.
- Optionally updates the zero-count ECS services to the latest task-definition revisions.
- Checks runtime SSM readiness before promotion by default.

The promotion workflow intentionally fails until these runtime sync steps have completed:

1. `sync-data-runtime.ps1`, after the RDS and Valkey stack exists.
2. `sync-scylla-runtime.ps1`, after the Scylla stack exists.

Use `deploy/aws/promote-image-tag.ps1` for the same local promotion flow. It runs `check-runtime-ready.ps1` unless `-SkipRuntimeCheck` is passed.

## Activation Sequence

After AWS account verification is resolved and the billable pieces are approved, the first canary activation flow is:

1. Create data services: `deploy-data-services.ps1 -Apply`.
2. Sync data URLs: `sync-data-runtime.ps1`.
3. Create Scylla: `deploy-scylla-ec2.ps1 -Apply`.
4. Sync Cassandra values: `sync-scylla-runtime.ps1`.
5. Confirm readiness: `check-runtime-ready.ps1`.
6. Push images to ECR with GitHub Actions or `build-push-images.ps1`.
7. Promote image tag: `promote-image-tag.ps1 -ImageTag <tag>`.
8. Scale ECS capacity: `scale-compute-ecs-ec2.ps1 -MinSize 1 -DesiredCapacity 1`.
9. Start a narrow canary: `scale-ecs-services.ps1 -Api 1 -Gateway 1 -MediaProxy 1 -Docs 1 -Apply -Wait`.
10. Check status: `get-deployment-status.ps1`.
11. Smoke-test public routes: `test-public-endpoints.ps1`.

If AWS keeps blocking EC2 but Fargate launches are allowed, the compute steps can change to:

1. Keep `atomic-radius-prod-ecs` at ASG desired `0`.
2. Use the Fargate fallback services.
3. Start a narrow canary with `scale-fargate-services.ps1 -Api 1 -Gateway 1 -MediaProxy 1 -Docs 1 -Apply -Wait`.

This does not solve the Scylla-on-EC2 block. For a full Fargate-only path, Cassandra/Scylla must be moved to an external provider, existing RackNerd temporarily, or a managed-compatible option.

## DNS and Certificate Readiness

The DNS and ACM certificate templates are staged but not applied:

- Hosted zone template: `dns-zone.yaml`
- Hosted zone deploy script: `deploy-dns-zone.ps1`
- ACM certificate template: `acm-certificates.yaml`
- ACM deploy script: `deploy-acm-certificates.ps1`
- DNS runtime sync script: `sync-dns-runtime.ps1`
- DNS status helper: `check-dns-status.ps1`

The hosted zone template prepares a public Route 53 hosted zone for `atomicradius.app`. This is billable when applied. By default, `deploy-dns-zone.ps1` only validates the template. To create the hosted zone later, run it with `-Apply`.

The `atomic-radius-dns-zone` CloudFormation stack was created in `us-east-1` on May 19, 2026.

Route 53 hosted zone:

- Hosted zone ID: `Z02245842APCLSUFF5WBG`
- Domain: `atomicradius.app`
- Name servers: `ns-385.awsdns-48.com`, `ns-645.awsdns-16.net`, `ns-1248.awsdns-28.org`, `ns-1723.awsdns-23.co.uk`

The `atomic-radius-dns-records` CloudFormation stack was created in `us-east-1` on May 19, 2026. It points:

- `atomicradius.app`
- `*.atomicradius.app`

to the Atomic Radius ALB.

Next user-side step: copy the Route 53 name servers to the domain registrar for `atomicradius.app`. ACM DNS validation will not complete until the registrar delegates the domain to the new hosted zone.

The ACM template prepares one DNS-validated certificate for:

- `atomicradius.app`
- `*.atomicradius.app`

The CloudFormation ACM stack was removed because CloudFormation waits for certificate issuance and rolls back while registrar delegation is pending. A standalone ACM certificate was requested instead. The pending certificate ARN is stored in SSM:

- `arn:aws:acm:us-east-1:817378414866:certificate/8f6f2f71-c76b-46e2-afa9-f1ad75f4530f`

The ACM DNS validation CNAME is already present in the Route 53 hosted zone:

- Name: `_13b8029bbd2616eab30348dacaae00b9.atomicradius.app.`
- Value: `_fedd29591aa1e247b258aae07a5d2eb1.jkddzztszm.acm-validations.aws.`

After registrar delegation propagates, ACM should issue the certificate. Then redeploy `deploy-edge-alb.ps1 -Apply` so the ALB adds HTTPS and redirects HTTP to HTTPS.

After `sync-dns-runtime.ps1`, ALB and CloudFront deploy scripts can automatically read:

- `/atomic-radius/prod/dns/hosted_zone_id`
- `/atomic-radius/prod/dns/domain_name`
- `/atomic-radius/prod/dns/name_servers`
- `/atomic-radius/prod/dns/certificate_arn`
