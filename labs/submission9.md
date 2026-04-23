# Lab 9 Submission - Monitoring and Compliance

## Task 1 - Falco Runtime Detection

### Environment and setup
- Started helper container: `alpine:3.19` as `lab9-helper`.
- Started Falco container with privileged mode, host mounts, Docker socket, and custom rules mount at `labs/lab9/falco/rules`.
- Falco JSON output evidence captured in `labs/lab9/falco/logs/falco.log`.

### Baseline/runtime alerts observed
From `labs/lab9/falco/logs/falco.log`:

1) **Fileless execution via memfd_create** (Critical)
- Rule: `Fileless execution via memfd_create`
- Container: `eventgen`
- Why this matters: fileless execution can bypass file-based security controls and is a common defense evasion behavior.

2) **Executing binary not part of base image** (Critical)
- Rule: `Drop and execute new binary in container`
- Container: `eventgen`
- Why this matters: this indicates container drift and potential malicious payload drop/launch after container start.

Additional observed alerts include:
- `Detected AWS credentials search activity`
- `Read monitored file via directory traversal`
- `Shell spawned by untrusted binary`
- `Netcat runs inside container that allows remote code execution`

### Custom Falco rule
Custom rule file: `labs/lab9/falco/rules/custom-rules.yaml`

- Rule name: `Write Binary Under UsrLocalBin`
- Purpose: detect writable file creation/modification under `/usr/local/bin` inside containers.
- Trigger validation: writing `custom-rule.txt` under `/usr/local/bin` in `lab9-helper` generated:
  - `Falco Custom: File write in /usr/local/bin ...`
  - Rule value in log: `Write Binary Under UsrLocalBin`

### Tuning / false positive notes
This custom rule is useful for catching unexpected in-container binary path writes (drift/tampering), but can fire during legitimate package installation, init, or update workflows. Practical tuning options:
- Exclude known installer processes (e.g., package managers) if required.
- Scope to production namespaces/images only.
- Add allowlist exceptions for approved maintenance containers.

## Task 2 - Conftest (Rego) Policy-as-Code

Policies reviewed:
- `labs/lab9/policies/k8s-security.rego`
- `labs/lab9/policies/compose-security.rego`

Manifests reviewed:
- `labs/lab9/manifests/k8s/juice-unhardened.yaml`
- `labs/lab9/manifests/k8s/juice-hardened.yaml`
- `labs/lab9/manifests/compose/juice-compose.yml`

### Conftest results
Saved outputs:
- `labs/lab9/analysis/conftest-unhardened.txt`
- `labs/lab9/analysis/conftest-hardened.txt`
- `labs/lab9/analysis/conftest-compose.txt`

1) **Unhardened Kubernetes manifest**
- Result: `30 tests, 20 passed, 2 warnings, 8 failures`
- Key failures:
  - image uses `:latest`
  - missing `runAsNonRoot: true`
  - missing `allowPrivilegeEscalation: false`
  - missing `readOnlyRootFilesystem: true`
  - missing resource requests/limits (cpu/memory)
- Warnings:
  - missing readiness probe
  - missing liveness probe

2) **Hardened Kubernetes manifest**
- Result: `30 tests, 30 passed, 0 warnings, 0 failures`
- Hardening that satisfied policy:
  - pinned image tag (`v19.0.0`, not latest)
  - `securityContext` with non-root, no privilege escalation, read-only root fs
  - capabilities drop includes `ALL`
  - resource requests and limits defined
  - readiness and liveness probes defined

3) **Docker Compose manifest**
- Result: `15 tests, 15 passed, 0 warnings, 0 failures`
- Compose security controls satisfied:
  - explicit non-root `user`
  - `read_only: true`
  - `cap_drop: ["ALL"]`
  - `security_opt` includes `no-new-privileges:true`

## Compliance and security analysis
- The policy failures in the unhardened deployment map directly to common attack paths: privilege escalation, unrestricted filesystem writes, and denial-of-service risk from missing resource limits.
- The hardened manifest demonstrates defense-in-depth by combining least privilege, immutability, and predictable resource governance.
- Falco runtime alerts complement static policy checks by detecting behavior at execution time (including post-deploy drift and suspicious syscall patterns).
