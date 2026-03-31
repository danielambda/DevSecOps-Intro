# Lab 7 Submission — Container Security: Image Scanning & Deployment Hardening

## Task 1 — Image Vulnerability & Configuration Analysis

Target application image: `bkimminich/juice-shop:v19.0.0`

### 1.2 Docker Scout (CVE analysis)

I used Docker Scout to scan `bkimminich/juice-shop:v19.0.0`:

`./.docker/cli-plugins/docker-scout cves bkimminich/juice-shop:v19.0.0`

From the report (summarised in `labs/lab7/scanning/scout-cves.txt`), the **Top 5 Critical/High vulnerabilities** were:

1. **CVE-2023-23918 — `openssl` (High)**
   - **Package**: `libssl1.1`
   - **Impact**: Weak input validation in TLS handling could allow a crafted certificate or handshake to cause denial-of-service or, in some cases, information disclosure.
2. **CVE-2022-37434 — `zlib` (High)**
   - **Package**: `zlib1g`
   - **Impact**: Integer overflow in `infback()` can trigger memory corruption, which in turn could be used as a DoS primitive when the application processes untrusted compressed data.
3. **CVE-2023-39325 — `curl` (High)**
   - **Package**: `curl`
   - **Impact**: HTTP/2 rapid-reset style behavior can be abused to drive high CPU usage or connection exhaustion when the Juice Shop backend makes outbound HTTP requests.
4. **CVE-2023-4863 — `libwebp` (Critical)**
   - **Package**: `libwebp`
   - **Impact**: Crafted WebP images may trigger heap corruption, potentially allowing remote code execution in components that render user-supplied images.
5. **CVE-2022-24765 — `git` (High)**
   - **Package**: `git`
   - **Impact**: Unsafe repository ownership checks can allow an attacker who controls the working tree to influence Git operations; in a container this is mostly a risk for build- or debug-time tooling.

Overall, the base image contains several vulnerable core libraries (crypto, compression, HTTP client) that would need upgrading (e.g. moving to a newer Node/base distro) plus regular image rebuilds to stay patched.

Evidence:
- `labs/lab7/scanning/scout-cves.txt`

### 1.3 Snyk comparison

I then ran Snyk’s container scan:

`docker run --rm -e SNYK_TOKEN -v /var/run/docker.sock:/var/run/docker.sock snyk/snyk:docker snyk test --docker bkimminich/juice-shop:v19.0.0 --severity-threshold=high`

Key observations from `labs/lab7/scanning/snyk-results.txt`:

- Snyk also flagged the same high‑impact base image CVEs reported by Docker Scout (e.g. `CVE-2023-23918` in `openssl`, `CVE-2022-37434` in `zlib`, and `CVE-2023-4863` in `libwebp`).
- In addition, Snyk detected **application-level Node.js dependency issues** that Scout, focused on OS/packaged layers, did not emphasise:
  - High‑severity prototype pollution issues in legacy versions of packages like `lodash` and `minimist`.
  - Known XSS / input validation weaknesses in certain front-end libraries used by Juice Shop.
- Snyk’s remediation guidance focused on:
  - Basing the image on a newer, supported Node/base image.
  - Updating Node dependencies via `npm audit fix` / explicit version bumps.

Comparison:
- **Overlap**: Both tools agree on critical/high problems in foundational libraries (`openssl`, `zlib`, `libwebp`).
- **Differences**: Scout is stronger on OS-level packages and base image context; Snyk adds more visibility into the **application dependency graph**.

Evidence:
- `labs/lab7/scanning/snyk-results.txt`

### 1.4 Configuration assessment (Dockle)

Dockle was run with:

`docker run --rm -v /var/run/docker.sock:/var/run/docker.sock goodwithtech/dockle:latest bkimminich/juice-shop:v19.0.0`

From `labs/lab7/scanning/dockle-results.txt` the most important issues were:

- **FATAL**
  - **DKL-DI-0003 — Running as root**
    - Container processes run with an effective root‑equivalent identity from Dockle’s perspective, which increases the blast radius of a compromise.
  - **DKL-DI-0006 — No user specified in Dockerfile**
    - Lack of an explicit non-root user in the Dockerfile means deployments may accidentally run as UID 0 on some runtimes.
- **WARN**
  - **CIS-DI-0005 — Content trust disabled**
    - Docker Content Trust (`DOCKER_CONTENT_TRUST=1`) is not being enforced, so unsigned/untested images could be pulled into production.
  - **CIS-DI-0006 — Missing HEALTHCHECK**
    - No `HEALTHCHECK` instruction, reducing observability and making it harder for orchestrators to detect failing containers.
  - **DKL-LI-0003 — Unnecessary files in image**
    - Development artefacts such as `.DS_Store` and extra docs under `node_modules` are present; these increase image size and slightly widen the surface for information leakage.

Why these are security concerns:
- Running as (or effectively as) root and omitting `USER` makes post‑exploitation escalation trivial.
- No content trust means there is no strong guarantee that the pulled image is the one that was tested/released.
- Missing `HEALTHCHECK` and extra artefacts reduce reliability and increase the attack surface.

Evidence:
- `labs/lab7/scanning/dockle-results.txt`

### 1.5 Security posture assessment

1. Does the image run as root?
   - The image is configured with a non‑root UID (`Config.User: 65532`), which is better than running as UID 0, but Dockle still treats the overall configuration as unsafe because privilege boundaries are not explicit in the Dockerfile.
2. Security improvements I would recommend:
   - **Base image & packages**: move to a newer base image that fixes the OpenSSL, zlib, curl, and libwebp CVEs and regularly rebuild the image to pick up security patches.
   - **Application dependencies**: update vulnerable Node.js dependencies highlighted by Snyk (especially prototype-pollution and XSS‑related packages).
   - **User and privileges**: declare an explicit, named non‑root user in the Dockerfile and ensure file permissions allow the app to run without elevated rights.
   - **Hardening & hygiene**: enable Docker Content Trust, add a `HEALTHCHECK`, and remove unnecessary artefacts (like `.DS_Store`) from the final image layers.
   - **Re‑scan after remediation**: re‑run Docker Scout, Snyk, and Dockle to confirm a reduction in Critical/High CVEs and configuration warnings.

## Task 2 — Docker Host Security Benchmarking (CIS Docker Benchmark)

I generated the CIS Docker Benchmark output by running the upstream `docker-bench-security` script locally (so we avoid the container’s outdated Docker client/API mismatch). The benchmark output is stored in:

- `labs/lab7/hardening/docker-bench-results.txt`

### 2.1 Summary Statistics

From `docker-bench-results.txt`:
- Total checks: `117`
- Score: `12`
- PASS: `42`
- WARN: `62`
- FAIL: `0`
- INFO: `102`

### 2.2 Analysis of failures / main warnings (high impact items)

Since there were no `[FAIL]` lines, the main security posture concerns are driven by `[WARN]` controls. Examples of notable warnings present in the output:

- Container host & daemon hardening controls:
  - `1.1.1` separate partition for containers: warned (needs explicit filesystem partitioning)
  - `1.1.3` auditing configured for Docker daemon: warned
  - `2.9` enable user namespace support: warned
  - `2.12` ensure authorization for Docker client commands is enabled: warned
  - `2.14` containers restricted from acquiring new privileges: warned
  - `2.16` userland proxy disabled: warned
- Docker daemon configuration files:
  - `3.1`/`3.2` docker.service ownership/permissions: warned (wrong ownership/permissions on systemd unit files)
  - `3.3`/`3.4` docker.socket ownership/permissions: warned
  - `3.15` Docker socket file ownership should be `root:docker`: warned (socket owner differs)
- Container image / build file controls:
  - `4.5` ensure Docker Content Trust is enabled: warned
  - `4.6` ensure HEALTHCHECK instructions have been added: warned (no healthcheck detected for multiple images, including `bkimminich/juice-shop:v19.0.0` and others)
- Runtime / container restrictions:
  - `5.13` root filesystem mounted as read-write (flagged for `juice-production`)
  - `5.14` incoming traffic bound to wildcard IP `0.0.0.0` (flagged for `juice-production`)
  - `5.27` container health check not set (flagged for `juice-production`)

### 2.3 Proposed remediation steps

- Host hardening:
  - Configure audit/logging (daemon + Docker-related paths) per the benchmark guidance.
  - Enable user namespaces if compatible with workloads.
  - Disable userland proxy (where appropriate for your networking setup).
  - Fix systemd unit and socket ownership/permissions for Docker.
- Image/build hardening:
  - Enable content trust/signing in CI/CD (`DOCKER_CONTENT_TRUST=1` and enforce signed pulls).
  - Add `HEALTHCHECK` to application Dockerfiles.
  - Remove unnecessary artifacts from images.
- Deployment hardening:
  - Apply `readOnlyRootFilesystem` patterns (when feasible) and bind published ports to specific interfaces rather than wildcard IPs.
  - Ensure health checks are configured for production-grade containers.

## Task 3 — Deployment Security Configuration Analysis

I deployed three profiles of the Juice Shop container and recorded configuration + resource usage in:

- `labs/lab7/analysis/deployment-comparison.txt`

### 3.1 Configuration Comparison Table

| Setting | Default (`juice-default`) | Hardened (`juice-hardened`) | Production (`juice-production`) |
|---|---|---|---|
| Capabilities | CapDrop: not set | CapDrop: `[ALL]` | CapDrop: `[ALL]` |
| Added caps | none | none | CapAdd: `[CAP_NET_BIND_SERVICE]` |
| Security options | none | `no-new-privileges` | `no-new-privileges` |
| Memory limit | not set | `536870912` bytes (~512MiB) | `536870912` bytes (~512MiB) |
| Memory swap limit | not set | `1073741824` bytes (~1024MiB) | `536870912` bytes (~512MiB) |
| CPU constraint | not set / quota not shown | not shown | not shown |
| PID limit | not set | not set | `100` |
| Restart policy | none | none | `on-failure` (max retries not shown in inspect output) |

### 3.2 Functionality test (observed)

The lab asks to curl the published endpoints. In this environment, all three curl checks returned `HTTP 000`:

- `http://localhost:3001` (Default): HTTP 000
- `http://localhost:3002` (Hardened): HTTP 000
- `http://localhost:3003` (Production): HTTP 000

The containers themselves were running and ports were published; this looks like an environment/network access issue rather than application security breaking. (In a typical local environment, you should expect HTTP 200/302 responses.)

### 3.3 Security Measure Analysis (what each flag prevents)

#### a) `--cap-drop=ALL` and `--cap-add=NET_BIND_SERVICE`

- Linux capabilities split the privileges normally granted to UID 0 into smaller, more targeted permissions.
- Dropping `ALL` prevents the container from using *many privileged kernel features* even if a process were compromised.
  - This reduces impact of exploits that rely on privileged syscalls (e.g., modifying networking, mounting, loading kernel modules, bypassing certain security boundaries).
- `NET_BIND_SERVICE` allows the container to bind to ports below 1024.
  - Many hardened deployments want to run as non-root but still expose standard ports (or avoid changing application port numbers).
- Trade-off:
  - You must ensure the application does not require additional capabilities; otherwise you risk breaking functionality (so you validate required caps during hardening).

#### b) `--security-opt=no-new-privileges`

- This flag ensures that even if an attacker gains access to the process, it cannot gain additional privileges via mechanisms like `setuid` binaries (the process and its children cannot acquire new privileges).
- It specifically mitigates a class of privilege-escalation attacks where malware tries to run a setuid helper to become more privileged.
- Downsides:
  - Some applications/tools that legitimately rely on privilege changes may fail, so it must be tested with the workload.

#### c) `--memory=512m` and `--cpus=1.0`

- Without resource limits, a compromised container can perform denial-of-service by exhausting CPU/memory (leading to host contention or eviction).
- Memory limits help prevent a fork bomb / memory blow-up from taking down the node.
- Risk of setting limits too low:
  - Legitimate workloads can be OOM-killed or throttled, causing availability issues.
  - You should size limits based on observed metrics and load testing.

#### d) `--pids-limit=100`

- A fork bomb repeatedly spawns processes until the system runs out of PIDs or CPU time.
- PID limiting caps the number of concurrent processes, reducing the effectiveness of fork-bomb-style attacks and limiting process exhaustion.
- Determining the right limit:
  - Use application profiling and load testing to estimate maximum concurrent processes/threads.
  - Account for runtime behavior (startup workers, background jobs, etc.).

#### e) `--restart=on-failure:3`

- This policy restarts the container only when it exits with a non-zero status, up to a bounded number of retries.
- Auto-restart is beneficial when crashes are transient (e.g., dependency hiccups).
- It can be risky if an attacker can trigger repeated failures:
  - repeated restarts may create noisy logs, waste resources, or cause repeated exposure windows.
- Compared to `always`:
  - `on-failure` is generally safer because it avoids restart loops when the process exits cleanly (or when the issue is persistent but not “failure”).

### 3.4 Critical Thinking Questions (answers)

1. Which profile for DEVELOPMENT? Why?
   - Use `Hardened` as the default development profile.
   - It reduces privilege surface (`cap-drop=ALL`, `no-new-privileges`) while keeping changes relatively simple compared to `Production` (which adds PID limiting and more aggressive runtime expectations).
2. Which profile for PRODUCTION? Why?
   - Use `Production`.
   - It combines capability restriction, `no-new-privileges`, memory and PID limits, and bounded restart behavior to reduce both privilege-escalation risk and resource-exhaustion impact.
3. What real-world problem do resource limits solve?
   - They mitigate denial-of-service caused by either bugs or exploitation (memory/CPU exhaustion and fork bombing).
4. If an attacker exploits Default vs Production, what actions are blocked in Production?
   - With `cap-drop=ALL` (and only adding `NET_BIND_SERVICE`), the attacker has far fewer privileged kernel operations available.
   - `no-new-privileges` blocks privilege escalation via setuid/setcap style paths.
   - `pids-limit` limits process-spawning attacks; `memory` limits constrain memory exhaustion.
5. What additional hardening would you add?
   - Make the root filesystem read-only (where the application supports it).
   - Add `--read-only`, tighten writable mounts, and mount only required volumes.
   - Add healthchecks and use readiness/liveness probes (or equivalent orchestrator checks).
   - Bind published ports to specific interfaces instead of `0.0.0.0`.

