# ADR 002: Automated Pre-Commit Quality & Secret Scanning Hooks

## Status
Accepted

## Context
As the repository grows, manual code formatting, manifest validation, and manual checking for hardcoded credentials/keys introduce human error. We need automated guardrails to prevent credentials or malformed Terraform code from entering the git history.

## Decision
We adopt the `pre-commit` framework (`.pre-commit-config.yaml`) to run automated checks locally prior to committing:
1. **Gitleaks (`gitleaks`)**: Automated sub-second scanning to prevent accidental commits of private keys, tokens, or credentials.
2. **Terraform Quality & Security (`pre-commit-terraform`)**: Automated formatting (`terraform_fmt`), syntax validation (`terraform_validate`), and documentation generation (`terraform-docs`).
3. **Kubernetes Validation (`kubeconform`)**: Strict schema validation for Kubernetes YAML manifests.
4. **Zero-Dependency Go Sandboxing (`language: golang`)**: Tools like `kubeconform` and `terraform-docs` use `language: golang` so `pre-commit` automatically builds and isolates binary dependencies without requiring manual host installation.
5. **Directory-Level Scoping (`pass_filenames: false`)**: Configured directory-scoped tools (`terraform-docs`) with `pass_filenames: false` to process target modules accurately without argument mismatches.
6. **File Hygiene**: Automatic trailing whitespace cleanup, end-of-file formatting, multi-document YAML parsing, and merge-conflict checking.

## Consequences
- **Positive:** Credentials and malformed code are blocked at commit time before reaching remote repositories.
- **Positive:** Enforces consistent canonical code style automatically across contributors.
- **Positive:** Zero host tool friction—`pre-commit` manages Go tool dependencies (`kubeconform`, `terraform-docs`) automatically in isolated environments.
- **Negative / Trade-off:** Requires contributors to install the core `pre-commit` CLI during workstation onboarding.
