# Spike: PR-Driven IDP (Terraform PR, no Crossplane)

## Goal

Prove the same Backstage UX as the Crossplane path, with **Terraform** as the provisioning engine.

| | Crossplane (today) | Terraform PR (spike) |
|---|---|---|
| Template | `s3`, `service`, … | `terraform-s3`, … |
| PR target | `prometeo-products/products/*/base/*.yaml` | `prometeo-products/products/*/terraform/*.tf` |
| Provision | ArgoCD sync → Crossplane | GHA `terraform plan` / `apply` |
| Catalog | `components/*.yaml` | Same |

Live PoC: [sb3.ims.iag.ai](https://sb3.ims.iag.ai/)

## Branch

```bash
# reference-implementation-aws
git checkout -b spike/terraform-pr

# prometeo-products
git checkout -b spike/terraform-pr
```

## Option A — Demo on sb3 (step by step)

### 1. Push branches (both repos)

```bash
# reference-implementation-aws
git checkout -b spike/terraform-pr
git push -u origin spike/terraform-pr

# prometeo-products
git checkout -b spike/terraform-pr
git push -u origin spike/terraform-pr
```

Merge `prometeo-products` workflow changes to `main` first (automerge skip + terraform-plan) so PRs from Backstage get a plan on `main`.

### 2. Point sb3 at the template branch

sb3 reads `repo.revision` from AWS Secrets Manager `cnoe-ref-impl/config` (see `config.yaml` → `packages/argo-cd/manifests/hub-cluster-secret.yaml`).

```bash
export AWS_PROFILE=<ims-admin-sb3-or-equivalent>

# Get current secret, update repo.revision, write back (or use your team's secret update process)
aws secretsmanager get-secret-value --secret-id cnoe-ref-impl/config --region eu-west-1

# Set repo.revision to: spike/terraform-pr
# Then re-run create-config-secrets.sh from this repo after editing config.yaml locally:
#   repo.revision: "spike/terraform-pr"
./scripts/create-config-secrets.sh
```

Wait ~15m for ExternalSecret refresh, or restart Argo CD hub-cluster-secret sync / patch the `hub-cluster` secret annotation `addons_repo_revision` directly for a faster test.

### 3. Refresh Backstage catalog

1. Open [sb3 Backstage](https://sb3.ims.iag.ai/catalog)
2. **Catalog → Locations → prometeo-templates** → refresh (scheduled entity refresh)
3. **Create** should show **S3 (Terraform PR)** alongside existing Crossplane templates

### 4. Demo script

| Step | Action |
|------|--------|
| A | Create → **S3 (Terraform PR)** → product `add`, name `exports`, bucket name |
| B | Open PR link → review `products/add/terraform/exports.tf` |
| C | Confirm `terraform-plan` workflow (after workflows merged to main) |
| D | Compare with Create → **S3** (Crossplane) → `base/*.yaml` PR |

### 5. Reset after demo

Set `repo.revision` back to `main` (or `HEAD`) in `cnoe-ref-impl/config` and refresh catalog.

## Day 1

1. Merge template registration (`templates/backstage/catalog-info.yaml`)
2. Confirm **Create → S3 (Terraform PR)** appears in Backstage
3. Add `products/<product>/terraform/backend.tf` (remote state) — hand-written once per product

## Day 2

1. Run template for product `add` → PR in `prometeo-products`
2. Verify `terraform-plan` workflow on PR
3. Merge + apply (manual or approved workflow)
4. Confirm bucket in AWS; Resource entity in catalog

## Out of scope

- Replacing Crossplane templates
- Removing ArgoCD ApplicationSet for `products/*/base`
- Entra auth (Keycloak on sb3 is fine for PoC)

## Module mapping (full spike)

| Crossplane template | Terraform module (`tf-common-modules`) |
|---|---|
| `service` | `bootstrap-service` |
| `statefulbackend` | `bootstrap-service` + `rds` |
| `database` | `rds` |
| `s3` | `s3` |
| `product` | `bootstrap-product` |
