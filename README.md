# Infrastructure

This repository provisions a maintainable, scalable GCP platform for:
- Spring Boot backend APIs
- PostgreSQL database
- Frontend hosting for web
- API support for mobile applications

## Checklist

- [x] Define target GCP architecture for backend, DB, and frontend
- [x] Standardize Terraform module + environment structure
- [x] Support full application lifecycle with `dev`, `qa`, and `prod`
- [x] Define CI/CD promotion gates and test strategy
- [x] Include security, observability, scaling, and cost controls

## Target Architecture (GCP)

- **Backend API**: Cloud Run (`api-service`) running Spring Boot containers from Artifact Registry
- **Database**: Cloud SQL for PostgreSQL (private IP, HA in prod)
- **Web Frontend**: Firebase Hosting + CDN (recommended) or Cloud Run static hosting
- **Mobile Clients**: Consume backend APIs; optional Cloud Run `mobile-bff` for mobile-specific composition
- **Ingress**: Global HTTPS Load Balancer + Cloud DNS + managed TLS certificates
- **Protection**: Cloud Armor WAF + rate limiting
- **Secrets/Keys**: Secret Manager + Cloud KMS
- **Observability**: Cloud Logging, Monitoring, Trace, Error Reporting, SLO dashboards/alerts

## Environment Model (Full-Fledged App Lifecycle)

### `dev`
Purpose:
- Rapid development and integration
- Frequent deployments from feature/develop branches

Characteristics:
- Lower-cost instance sizing
- Relaxed autoscaling limits
- Ephemeral test data allowed

### `qa`
Purpose:
- System/integration/UAT validation before production
- Stable environment for test cycles

Characteristics:
- Production-like config for critical services
- Controlled refresh of sanitized data
- Performance regression checks and release sign-off

### `prod`
Purpose:
- Live customer traffic

Characteristics:
- HA Cloud SQL, strict IAM, stronger WAF rules
- Tight SLO/SLA alerts and on-call routing
- Controlled change windows and manual approvals

## Isolation Strategy

Recommended default: **separate GCP project per environment**
- `howzy-dev`
- `howzy-qa`
- `howzy-prod`

Per environment:
- Dedicated VPC/subnets/firewall policies
- Separate service accounts and IAM bindings
- Separate secrets and KMS keyrings
- Separate monitoring alert policies and budgets

## Terraform Layout

```text
terraform/
  modules/
    network/
    cloud_sql_postgres/
    cloud_run_service/
    artifact_registry/
    dns_tls/
    security/
    observability/
  environments/
    dev/
      backend.tf
      main.tf
      variables.tf
      terraform.tfvars
    qa/
      backend.tf
      main.tf
      variables.tf
      terraform.tfvars
    prod/
      backend.tf
      main.tf
      variables.tf
      terraform.tfvars
```

Conventions:
- Put reusable logic in `modules/`
- Keep environment values only in `environments/<env>/terraform.tfvars`
- Use remote state in GCS (separate state prefix per env)
- Use `terraform fmt`, `validate`, and policy checks in CI

## CI/CD and Promotion Flow

Branching model used by this repository:
- `dev` branch -> deploys to `dev`
- `qa` branch -> deploys to `qa`
- `main` branch -> deploys to `prod`

Promotion path:
1. Feature branch -> PR into `dev`
2. Promote tested changes from `dev` -> `qa`
3. Promote validated release from `qa` -> `main` (`prod`)

Pipeline gates:
- Build + unit tests
- Container image scan
- Terraform plan + policy checks
- DB migration step before traffic shift
- Canary rollout with automatic rollback on SLO breach

## Test and Data Strategy

- **dev**: unit + component + basic integration tests; synthetic data
- **qa**: integration + contract + UAT + non-functional checks; sanitized production-like data
- **prod**: smoke checks post-deploy, continuous SLO checks, no destructive testing

## Security Baseline

- Least-privilege IAM and dedicated service accounts
- Workload Identity where possible (avoid long-lived keys)
- Secret Manager for credentials, never commit secrets in repo
- Cloud SQL private networking only in `qa`/`prod`
- Organization policies/audit logs enabled

### Secret Manager Integration (Frontend + Backend Repos)

- Secrets are provisioned per environment project (`howzy-dev`, `howzy-qa`, `howzy-prod`).
- Core app secrets are `db-password` and `jwt-secret`.
- Cloud Run API and `mobile-bff` consume secrets directly from Secret Manager (no plaintext in repo or pipeline vars).
- Grant repo-specific deploy identities via `secret_accessor_members` in each environment tfvars (for separate frontend/backend repos).
- Optional bootstrap secrets can be added with `provided_secret_values` in each environment tfvars.

## Observability and Operations

- Define SLOs for availability, latency, and error rate per service
- Central dashboards per environment
- Alert tiers: warning (team channel), critical (on-call)
- Runbooks in `docs/runbooks/` for incidents and rollback steps

## Cost Management

- Budget + alert per environment
- Environment-specific autoscaling limits
- Log retention policies and image cleanup
- Review committed-use discounts after steady production usage

## Rollout Phases

1. **Foundation**: projects, IAM, remote state, VPC, Artifact Registry
2. **Core Services**: Cloud SQL, backend API, secrets, DNS/TLS
3. **Quality/Security**: QA parity, WAF, observability, release gates
4. **Scale/Resilience**: read replicas, DR drills, cost optimization

## Next Implementation Step

The Terraform baseline scaffold is now in place under `terraform/modules` and `terraform/environments/dev|qa|prod`.

Use these commands per environment after creating `terraform.tfvars` and `backend.hcl` from examples.

```bash
terraform -chdir=terraform/environments/dev init -backend-config=backend.hcl
terraform -chdir=terraform/environments/dev plan

terraform -chdir=terraform/environments/qa init -backend-config=backend.hcl
terraform -chdir=terraform/environments/qa plan

terraform -chdir=terraform/environments/prod init -backend-config=backend.hcl
terraform -chdir=terraform/environments/prod plan
```

## Delivery Automation Added

### GitHub Actions

- `terraform-ci.yml`
  - Runs on PR/push for `dev`, `qa`, and `main`
  - Executes Terraform `fmt` + `validate` for `dev|qa|prod` environment dirs
- `terraform-apply.yml`
  - Runs on push to `dev|qa|main` and maps branch to environment automatically
  - `dev` -> `dev`, `qa` -> `qa`, `main` -> `prod`
  - Also supports manual dispatch, with branch/environment mismatch protection

Important for production approvals:
- Set up a GitHub Environment named `prod`
- Configure required reviewers in that environment
- `terraform-apply.yml` uses `environment: prod` for `main` branch runs, so apply pauses for approval

Required GitHub secrets for `terraform-apply.yml`:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_TERRAFORM_SA`
- `TFSTATE_BUCKET_DEV`, `TFSTATE_BUCKET_QA`, `TFSTATE_BUCKET_PROD`
- `TFVARS_DEV`, `TFVARS_QA`, `TFVARS_PROD`
