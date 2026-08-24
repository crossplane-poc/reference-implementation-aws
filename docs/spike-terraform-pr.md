# ITAL-1925 — Backstage driving Terraform directly (vs Crossplane)

Spike branch: **`ITAL-1925/terraform-pr`** (both `reference-implementation-aws` and `prometeo-products`)

## Questions to answer (Jira)

### 1. Backstage ↔ Terraform integration — what exists, how mature?

| Integration | Maturity | Notes |
|---|---|---|
| **Scaffolder → PR with `.tf`** (our path) | **Production-proven pattern** | Not a special Backstage plugin — `publish:github:pull-request` + `roadiehq:utils:fs:write`. Same as current Prometeo templates, different file output. |
| **`catalog:write` / entity YAML** | Stable | Catalog metadata stays in Git; no Crossplane required. |
| **Official "Terraform" Backstage plugin** | Limited | No first-class "run terraform apply from Backstage" core plugin. Orchestration is CI (GHA) or custom actions. |
| **CNOE `cnoe template tf`** | Early / auxiliary | CLI to generate templates from modules — accelerator, not runtime. |
| **Argo Workflows + Terraform** (CNOE example) | Optional | Cluster workflow runs TF; heavier than GHA for our existing `workflows` repo. |

**Conclusion:** Maturity is in **PR + CI + modules**, not in a Backstage-Terraform coupling. Backstage's job is **form → PR → catalog entity**; Terraform runs in **GitHub Actions** (same as today for `platform-*-aws-mgmt`).

### 2. Who does reconciliation, state, drift detection?

| Concern | Crossplane + ArgoCD path | Terraform PR path |
|---|---|---|
| **Desired state** | Git (`base/*.yaml` CRs) | Git (`terraform/*.tf`) |
| **Apply** | ArgoCD sync → Crossplane reconciler | GHA `terraform apply` on merge |
| **State** | Crossplane + K8s etcd (CR status) | **S3 + DynamoDB** TF backend (existing platform pattern) |
| **Reconciliation** | Crossplane **continuous** — retries until spec matches AWS | **Event-driven** — plan on PR, apply on merge; drift on next plan/scheduled run |
| **Drift detection** | Crossplane status + ArgoCD OutOfSync | **`terraform plan`** (PR + optional scheduled workflow) |
| **"Keep retrying until success"** | **Crossplane wins** — control loop in cluster | **Terraform loses** unless you add automation (e.g. failed apply alerts, re-run workflow) |

**Conclusion:** You **trade continuous K8s-native reconciliation** for **familiar TF state + PR review**. Drift is detected by **plan**, not by CR `.status`. Production teams already operate this way on `platform-*-aws-mgmt`.

### 3. Status / health back into Backstage without Crossplane CRs?

| Signal | How |
|---|---|
| **Catalog entity** | `components/*.yaml` / `Resource` — **written by template** (same as today) |
| **Provisioning status** | PR checks (plan pass/fail), merge state — **GitHub plugin** or custom annotation (`iag.ai/terraform-pr: #123`) |
| **AWS resource health** | **Not automatic** — optional: TF outputs → update catalog via workflow, AWS API custom provider, or manual annotations |
| **K8s workload health** | **Unchanged** — K8s / ArgoCD plugins on `Component` (apps still deploy via ArgoCD or GHA) |
| **Live inventory sync** | Crossplane: CR status fields. TF: **no built-in catalog sync** — catalog describes intent in Git; plugins show runtime |

**Conclusion:** Backstage catalog stays **Git-defined** (entities + relations). Runtime health comes from **plugins** (GitHub, ArgoCD, K8s, Datadog) — not from Crossplane CR `.status`. You lose **automatic infra status on the Resource entity** unless you build a small sync (tags → entity provider, or workflow updates YAML).

### 4. What we lose vs gain vs Crossplane path?

| | Lose (TF direct) | Gain (TF direct) |
|---|---|---|
| Ops model | Continuous reconcile, CR status in cluster | **Team already runs TF**; no new control plane to learn |
| Unified K8s+AWS in one API | Single XR models app+AWS | Clear split: TF = AWS, ArgoCD = K8s apps |
| Dependency graph in cluster | Composition chains XRs | **Module composition in HCL** + explicit ordering in PRs |
| Retry behaviour | Automatic until success | Explicit CI retry / human fix |
| sb3 PoC alignment | Already built Prometeo XRs | **Reuses `tf-common-modules`** — no XR/composition layer |
| GitOps for infra | ArgoCD applies CRs | **PR + plan comment** — stronger review gate for shared accounts |
| Production experience | None yet (Evgeny's concern) | **Platform already provisions via TF in prod** |

**Hybrid (likely end state):** TF for foundation + most app infra; Crossplane only if a PoC proves value for fast/disposable app resources.

### 5. Where does production risk sit?

| Risk area | Crossplane + TF provider | Backstage → Terraform PR |
|---|---|---|
| **New technology** | **High** — Crossplane ops, compositions, CRDs, provider bugs, no prod experience | **Low** — same TF modules + GHA as today |
| **Blast radius** | Mis-synced CR can loop/reconcile unexpected changes | Mis-merged PR — mitigated by **plan review**, branch protection |
| **State corruption** | CR + TF state dual truth if TF provider used inside Crossplane | **Single TF state** — well-understood recovery |
| **Security / IAM** | Crossplane provider needs broad AWS per composition | **OIDC GHA role** — existing `workflows` pattern |
| **Team skills** | Platform learns Crossplane + K8s debugging | **Developers + platform already know TF PRs** |
| **Evgeny's concern** | **Primary risk: no Crossplane prod experience** | Risk shifts to **process** (who approves PRs, module contracts) — not new runtime |

**Recommendation for decision:** Run **ITAL-1925 spike on sb3** (both templates side by side). If TF PR meets self-service + audit needs, **default to TF direct** for platform products; keep Crossplane as optional only where continuous reconcile justifies the ops cost.

---

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
git checkout -b ITAL-1925/terraform-pr

# prometeo-products
git checkout -b ITAL-1925/terraform-pr
```

## Option A — Demo on sb3 (step by step)

### 1. Push branches (both repos)

```bash
# reference-implementation-aws
git checkout -b ITAL-1925/terraform-pr
git push -u origin ITAL-1925/terraform-pr

# prometeo-products
git checkout -b ITAL-1925/terraform-pr
git push -u origin ITAL-1925/terraform-pr
```

Merge `prometeo-products` workflow changes to `main` first (automerge skip + terraform-plan) so PRs from Backstage get a plan on `main`.

### 2. Point sb3 at the template branch

sb3 reads `repo.revision` from AWS Secrets Manager `cnoe-ref-impl/config` (see `config.yaml` → `packages/argo-cd/manifests/hub-cluster-secret.yaml`).

```bash
export AWS_PROFILE=<ims-admin-sb3-or-equivalent>

# Get current secret, update repo.revision, write back (or use your team's secret update process)
aws secretsmanager get-secret-value --secret-id cnoe-ref-impl/config --region eu-west-1

# Set repo.revision to: ITAL-1925/terraform-pr
# Then re-run create-config-secrets.sh from this repo after editing config.yaml locally:
#   repo.revision: "ITAL-1925/terraform-pr"
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
