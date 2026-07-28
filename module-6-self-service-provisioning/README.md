# Module 6 — Self-Service Provisioning VMs with Red Hat Developer Hub

**Documentation only in this pass** — deferred, per the project's agreed scope (this and disconnected/mirroring tooling were explicitly pushed to a later phase so the core lab — portal → travels VM → mesh → GitOps, modules 0–5 — lands solid first).

## What the official lab covers

Module 6 of the official lab introduces Red Hat Developer Hub (RHDH) — an internal developer portal built on Backstage — as a self-service front-end for provisioning VMs. The official module has no real hands-on walkthrough itself: `m6/walkthrough.adoc` is just an embedded interactive demo video, not executable steps or manifests. There's nothing to port from source for this module beyond that concept.

RHDH's role in this architecture, per the lab's intro material:
- **Software Templates** — automate repo setup and VM/app scaffolding (would plug into this repo's module structure as a template source).
- **Centralized Dashboard** — single pane of glass across Git, OpenShift, CI/CD, docs.
- **Dynamic Plugins** — Tekton, GitOps, Argo CD integration without redeploying RHDH itself.
- **RBAC** — govern who can self-provision what.

## What a future implementation pass would need

- Red Hat Developer Hub operator install (`common/operators/`).
- A Backstage *Software Template* that wraps Module 0's VM manifests (or the Module 5 Helm chart pattern) as a parameterized "provision a new travel-agency-style VM" action, committing the result back to this repo for ArgoCD to pick up — i.e., RHDH becomes a UI on top of the same GitOps flow Module 5 already established, not a replacement for it.
- RBAC scoping so self-service is limited to namespaces/templates appropriate for the requester.

Not built here. If/when this phase is picked up, it composes with the existing repo rather than changing it: RHDH would generate PRs/commits into `module-0-bootstrap`-style manifests and let the Module 5 GitOps layer do the actual deployment.
