# Things we could have done differently

Every decision behind [`MULTI-ENV-PROMOTION.md`](./MULTI-ENV-PROMOTION.md), what we picked, what we
gave up, and what would make us change our minds.

Nothing here is settled forever. The order is roughly "most worth arguing about" first.

---

## 1. How many ArgoCDs

**Picked: one ArgoCD (hub-and-spoke), with prd already split into its own ApplicationSet and
AppProject so it can be moved out cheaply.**

| option | good | bad |
|---|---|---|
| **One ArgoCD, all four clusters** *(picked)* | One place to look. One RBAC model. One upgrade. Cheapest to run. The mainstream pattern — it is what AWS's own EKS Blueprints hub-and-spoke reference does. | The hub is a single point of compromise: whoever controls it can deploy to production. Its outage is everyone's outage. Blast radius is contained by AppProjects, which is policy, not isolation. |
| **Two ArgoCDs: non-prod and prd** | Production's control plane is not the one developers log into every day. Compromising the dev hub does not reach prd. Common in regulated organisations, and the usual end state. | Two instances to run, upgrade and back up. Two RBAC configurations that will drift. Promotion still crosses the boundary, so the boundary buys less than it looks like it does. |
| **One ArgoCD per environment** | Maximum isolation. An environment's outage is only its own. | Four upgrades, four sets of credentials, four UIs. Nobody can see the whole estate. Cost and toil grow linearly with environments, which is the thing hub-and-spoke exists to avoid. |
| **Argo CD Agent / pull-based spokes** | No inbound access from hub to spoke at all: the spoke pulls. The strongest network story. | Newer, less deployed. An agent to run in every cluster. Overkill at four clusters. |

**Why one:** at four clusters, one control plane is the honest answer, and the second one is a cost
we should pay when there is something to protect. Everything prd-specific is already in its own
files — `applicationset-prometeo-products-prd.yaml`, `appproject-prometeo-prd.yaml`, the
`prometeo.iag.ai/hub: prd` label — so splitting it is moving three files, not a redesign.

**Revisit when:** production carries real customer data, or an auditor asks who can deploy to prd
and the honest answer includes "anyone who can get into the dev cluster's ArgoCD".

---

## 2. Kargo, or a script

**Picked: a script (`promote.py`) plus a GitHub Actions workflow. No Kargo.**

[Kargo](https://kargo.io) is Akuity's promotion orchestrator, and what we built is a smaller
version of its core idea. Kargo's "Freight" is a set of artefact versions that moves through
"Stages" — which is exactly what our Release is.

| | good | bad |
|---|---|---|
| **Script + Actions** *(picked)* | ~250 lines of Python we can read in one sitting. No new controller, no new CRDs, no new UI to secure. The approval gate is GitHub's, which we already use and already audit. Works identically on a laptop and in CI. | We own it. No freight lineage across products. No automatic promotion, no soak windows, no verification gates — a human decides, every time. |
| **Kargo** | Promotion becomes declarative: watch a stage, verify it, promote when it passes. Soak windows, automatic promotion, subscriptions to image repos, and a UI showing where every version is. Its verification step is the missing piece we called out as future work. | Another controller and another CRD set in every cluster. Another RBAC surface. A second place promotion policy lives, which has to agree with GitHub's. Real learning curve for something we currently do once a week. |

**Why not yet:** the honest test is whether we need *orchestration* or just *a promotion*. Today we
need a promotion — someone decides, a pull request is opened, a human approves. That is a script.
Kargo earns its place when we want "promote to uat automatically once tst's smoke tests have passed
and it has soaked for two hours", and that is a question we cannot answer until there are smoke
tests to soak.

The Release file is deliberately shaped like Freight — a component set plus pinned digests plus
provenance — so adopting Kargo means pointing it at these files, not redesigning around it.

**Revisit when:** we want automatic promotion on green verification, or promotion policy differs
per product, or more than about ten products make the manual step a bottleneck.

---

## 3. What the unit of promotion is

**Picked: the whole Release — every component and every image, together.**

| option | good | bad |
|---|---|---|
| **Whole release** *(picked)* | You promote the combination that was actually tested. One decision, one pull request, one thing to roll back. Provenance is simple: tst is running dev's release `a5fd44d7c70a`. | You cannot ship an urgent backend fix without also shipping whatever else landed in dev. Encourages a busy dev branch to block releases. |
| **Per service** | Ship one fix without the rest. Familiar to anyone from a microservice shop. | You deploy a combination nobody ran anywhere. "What is in tst" stops being a single answer. Rollback is per-service and the interactions are yours to reason about. |
| **Per component** | Finest control. Promote a bucket without promoting a service. | Same as above, more so, and now infrastructure changes are also unsequenced. |

**Why whole:** the value of an environment ladder is entirely in "this exact combination worked one
rung down". Partial promotion spends that, and it is the only thing the ladder was buying.

The pressure valve, when a hotfix is genuinely needed, is a **fix-forward through dev**: land it in
dev, let dev settle, promote. If dev is too unstable for that to be fast, that is a signal about
dev, not an argument for partial promotion.

**Revisit when:** a real incident is made worse by having to drag unrelated changes along. If that
happens twice, add `--only <service>` and accept the cost knowingly.

---

## 4. How environments differ from each other

**Picked: one `EnvironmentConfig` per cluster (already existed) + a per-environment `overrides.yaml`
for sizing.**

The component manifests contain no environment at all. Names, accounts, VPCs and domains are
resolved by Crossplane from the target cluster's `EnvironmentConfig` at apply time.

| option | good | bad |
|---|---|---|
| **EnvironmentConfig + overrides.yaml** *(picked)* | Promotion is a file copy, because there is nothing environment-shaped in the file being copied. Sizing and application config are separate and never promoted, so prd cannot inherit dev's replica count or its debug logging. Any field on any component can be overridden, so there is no list of "overridable settings" to keep up to date. | Three places to look when asking "why is this value what it is". A missing `EnvironmentConfig` fails at reconcile time, not at review time. |
| **Helm values per environment** | Familiar. One chart, four values files. Rich templating. | Reintroduces templating between the pull request and the cluster — the diff a reviewer sees stops being the change. Charts drift into conditionals nobody can read. |
| **Kustomize overlays per environment** | Standard, ArgoCD ships it, patches are explicit. | The overlay has to name every resource it patches, so scaffolding a component means editing a `kustomization.yaml` — the exact thing this repo removed on purpose. |
| **A full copy of the manifests per environment** | Dead simple. Nothing to learn. | Four copies of every file, drifting. "dev and tst differ only in X" becomes unprovable. |

**Why:** it was already true, and it is the property that makes everything else cheap. It is worth
saying plainly — the reason promotion is a file copy here, and a rewrite in most organisations, is
that this platform put the environment in the cluster instead of in the manifest.

---

## 5. Rendered manifests in git, or templating at sync time

**Picked: render in CI, commit the output, ArgoCD syncs plain YAML.**

| option | good | bad |
|---|---|---|
| **Rendered, committed** *(picked)* | The promotion pull request is the literal diff of what changes in the cluster. No template to evaluate during review of a production change. ArgoCD does no templating, so sync cannot surprise you. Git history is a record of what actually ran. | Generated files in git. Needs a CI job to keep them fresh and a check that they are. Repository gets bigger. |
| **Helm/Kustomize at sync time** | DRY. No generated files. The normal thing. | Reviewing a production change means reading a template and imagining the output. Argo's diff shows the result, but only after the change is already merged. |
| **ArgoCD Source Hydrator** | Native version of what we built: ArgoCD renders and pushes to a hydrated branch itself. No CI job. | Off by default and still settling. Pushes only to its own branch — it does not open the pull request, which is the part we actually wanted. |

**Why:** the whole design is "the pull request is where the decision is made". That only works if
the pull request shows the decision. Everything else is downstream of that.

**Revisit when:** the Source Hydrator is stable and can be pointed at a pull-request flow. Then the
CI job goes away and the pattern stays.

---

## 6. How image versions get into git

**Picked: the service's build pipeline pins repository, tag and digest in dev's Release.**

| option | good | bad |
|---|---|---|
| **Pipeline writes the pin** *(picked)* | Git is the record. The digest is captured at build time, so what was tested is what promotes. Auditable, and works the same in every environment. | Every service repo needs the extra step. Cross-repo write access to configure. |
| **ArgoCD Image Updater** | No pipeline change. Watches the registry, writes back to git. | Another controller. Registry-driven, so it wants a tag pattern per environment — and the moment you promote by tag pattern rather than digest, "what is in prd" is whatever the tag pointed at last. |
| **A tag per environment (`:tst`, `:prd`)** | Trivial. No git write at all. | Mutable tags. Nothing records what was deployed or when. Rollback means re-tagging. Cannot answer "what exactly is running in prd" without asking the registry, which may have moved on. |

**Why digest, not tag:** a tag is a name someone can point somewhere else; a digest is the bytes.
The whole claim of an environment ladder — "this passed tst" — is only true if prd runs the same
bytes tst ran. Tags do not give you that; digests do, for free.

---

## 7. Where the promotion logic lives

**Picked: a script and a GitHub Actions workflow. Backstage is only the button.**

| option | good | bad |
|---|---|---|
| **Actions workflow** *(picked)* | Runnable locally, testable, reviewable. GitHub Environments give the approval gate for free, audited by GitHub. Backstage being down does not block a release. | Two systems to look at when something goes wrong. Backstage's confirmation is a link, not a result. |
| **Backstage scaffolder does it directly** | One system. Immediate feedback and a pull request link in the UI. | Promotion logic in Jinja inside a template — hard to test, impossible to run locally. The approval gate becomes Backstage's, which is weaker and less audited. Backstage down means nobody can promote. |
| **An ArgoCD plugin / sync hook** | Closest to where deployment happens. | Promotion becomes invisible to git review, which is exactly what we are trying to avoid. |

**Why:** the gate should live where the audit trail already is. GitHub already knows who approved
what and keeps the record; a Backstage template would be a second, weaker copy of that.

---

## 8. Pinning `componentsRevision`, or tracking `main`

**Picked: every environment above dev pins the commit its component files come from.**

| option | good | bad |
|---|---|---|
| **Pin the revision** *(picked)* | An edit to a component file reaches dev now and prd only when promoted. Makes auto-merging Backstage pull requests safe. Promotion is genuinely atomic — definitions and images move together. | One more concept. Rendering an old environment reads files from an old commit, which surprises people the first time. A long-unpromoted environment renders from a very old tree. |
| **Everything tracks `main`** | Simpler. One version of each component file, ever. | A component edit is live in production at the next render, having passed through no environment. Auto-merge would have to go. This is the failure mode the whole ladder exists to prevent. |
| **A branch per environment** | Familiar. `git merge` is the promotion. | Environment-local settings live on the branch and conflict forever. Cherry-picking becomes normal. Notoriously painful at scale, and the reason the industry moved to directories. |

**Why:** without the pin, only images are promoted and configuration is not — which is exactly the
half-solution the brief asked us to avoid.

---

## 9. Auto-merge

**Picked: keep it, but only for pull requests that cannot reach an environment above dev.**

The repository auto-merged everything, on the sound reasoning that creating a component file does
not deploy anything. That stops being true the moment prd lives in the same repository.

| option | good | bad |
|---|---|---|
| **Path-scoped auto-merge** *(picked)* | Scaffolding stays instant, which is the point of the portal. Promotions get a human. The rule is one grep in one file. | A path list to maintain. A new directory that nobody adds to the list silently needs review — which is the safe direction to fail. |
| **Drop auto-merge entirely** | One rule, no exceptions. | Every "add a bucket" waits on a reviewer who has nothing to review. Kills the self-service story. |
| **Keep it unconditional** | Nothing to change. | A bot merges production promotions. |

Note it fails safe: an unrecognised path is treated as needing review, not as safe.

---

## 10. Smaller calls

**One repository for all products, or one per product.** Kept one. Cross-product changes are a
single pull request and the ApplicationSet stays one object. Split it if a product needs different
reviewers than the platform team — the layout is per-product already, so splitting is a `git
filter-repo`, not a redesign.

**Four rungs, or fewer.** Four because the brief asked for four. uat is the one to question: if
nobody does business acceptance in it, it is a soak environment with an expensive name, and
`dev → tst → prd` is cheaper and faster.

**`environment: sb3` on the dev rung.** The ladder rung is `dev`; the AWS environment name is still
`sb3`, because every resource in that account is already named after it and renaming means
recreating them. The rung lives on the ArgoCD cluster Secret, the AWS name in the
`EnvironmentConfig`. They converge when a real dev account exists.

**Deleting a component.** Removing a file removes it from dev at the next render; higher
environments drop it only when a promotion removes it from their component list. Nobody has tested
what Crossplane does with the orphaned Terraform workspace, and a component that was deleted in dev
but still lives in prd is a state worth having an opinion about before it happens.
