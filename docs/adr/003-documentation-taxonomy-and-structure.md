# ADR 003: Documentation Architecture Taxonomy

## Status
Accepted

## Context
Combining infrastructure specifications, host networking topologies, security posture details, developer onboarding steps, and operational commands into a single monolithic document creates maintenance overhead and confuses different target audiences.

## Decision
We adopt a decoupled, standard production documentation taxonomy:
1. **`README.md`**: Project overview, architectural summary, and quick navigation index.
2. **`DEVELOPMENT.md`**: Developer onboarding, toolchain prerequisites, pre-commit hook setup, and local execution workflows.
3. **`docs/environment.md`**: Infrastructure environment specifications, L2 Linux bridge networking, RBAC groups, and host AppArmor security posture.
4. **`docs/adr/`**: Architecture Decision Records capturing technical rationale and design evolution.

## Consequences
- **Positive:** Clear separation of concerns between operational developer guides and environment specs.
- **Positive:** Aligns repository structure with enterprise and open-source production best practices.
- **Negative / Trade-off:** Documentation updates must be maintained across multiple files.
