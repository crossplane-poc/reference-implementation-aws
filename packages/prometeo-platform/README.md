# Prometeo component platform

The Crossplane layer that turns a manifest in
[crossplane-poc/prometeo-products](https://github.com/crossplane-poc/prometeo-products) into AWS
infrastructure.

ArgoCD syncs **`environments/<rung>/`**, not this directory directly — one Application per rung,
wired as `prometeo-platform-<rung>` in `packages/addons/values.yaml` and selected by the
`prometeo.iag.ai/rung` label on the cluster's ArgoCD Secret. Today only `dev` resolves, to the sb3
control plane (`ims-eu-west-1`, account `515048895486`); the other three generate no Application
until those clusters are registered.

Each rung is the same platform plus one file:

```sh
kubectl kustomize environments/dev | grep -c '^kind:'          # 22
diff <(kubectl kustomize environments/dev) \
     <(kubectl kustomize environments/prd)                     # only the EnvironmentConfig
```

That single differing file is the entire environment-specific surface of the platform, and it is
why a component manifest can be promoted between environments unchanged. See
[`docs/MULTI-ENV-PROMOTION.md`](../../docs/MULTI-ENV-PROMOTION.md).

## How a component runs

```
   an XR  ──►  its Composition
                    │  renders a Terraform root module + its variables
                    ▼
              Workspace  (tf.m.upbound.io)
                    │
          provider-terraform pod
                    │  terraform init / plan / apply, re-planned every 30 minutes
                    ▼
              one tf-common-module
                    │
       AWS + this cluster's namespaces, ingresses, network policies
```

Nothing rewrites the Terraform. There is one component per module, and the composition's whole
job is translating camelCase spec fields into snake_case module variables.

## Layout

| | wave | |
|---|---|---|
| `packages/` | -20 | The three composition functions and `provider-terraform`, with the pod it runs in |
| `config/` | -10 | Workspace activation, the provider's in-cluster RBAC, and the root-module plumbing. Identical in every environment |
| `environments/<rung>/` | — | The entry point ArgoCD syncs: the three directories above plus that rung's `EnvironmentConfig` |
| `components/` | 0 | One XRD + Composition per module: `Product`, `AppService`, `PostgresDatabase`, `ObjectStore`, `KeyValueTable`, `MessageQueue` |

The waves matter: each directory needs CRDs the previous one installs.

## Two things are not in git, and cannot be

**`tf-modules-deploy-key`** — `tf-common-modules` is private, so `terraform init` clones it over
SSH from inside the cluster. The provider pod mounts the key through `GIT_SSH_COMMAND`:

```sh
kubectl create secret generic tf-modules-deploy-key -n crossplane-system \
  --from-file=ssh=$HOME/.ssh/tf-common-modules-deploy-key
```

**`prometeo-terraform-provider`** — the IAM role the provider pod assumes, referenced by the IRSA
annotation in `packages/22-provider-terraform.yaml`. Much broader than the AWS providers' role,
because Terraform creates whatever the modules create.

Both already exist in sb3. A rebuild elsewhere needs them created first.

## The Terraform version wall

`provider-terraform` is frozen at Terraform 1.5.7 and will not adopt a BSL-licensed release, while
every `tf-common-modules` module declares `required_version = ">= 1.13"`. On the stock image every
apply dies at `terraform init` with *"This configuration does not support Terraform version
1.5.7"*. `provider-opentofu` does not help — its current release ships OpenTofu 1.10.8, which also
fails `>= 1.13`.

`packages/22-provider-terraform.yaml` therefore points at a custom image,
`515048895486.dkr.ecr.eu-west-1.amazonaws.com/prometeo/provider-terraform:v1.1.1-tf1.13-r3` — a
three-line Dockerfile over the upstream runtime. Any plan to run these modules under Crossplane
owns a provider image from day one.

## Reading a failed apply

The Workspace's condition carries only the last error line. `enableTerraformCLILogging` is set on
every composed Workspace, which sends Terraform's own stdout to the provider pod's log — that is
where the real reason lives:

```sh
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform --tail=200
```

State lives in the **kubernetes backend** — Secrets in `crossplane-system`, one per Workspace —
not in the IMS S3 bucket. A control plane that re-plans every 30 minutes must not share state with
the CI pipeline that owns the Terraform-only products.
