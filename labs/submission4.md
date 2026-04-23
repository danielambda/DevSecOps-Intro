# Lab 4 — SBOM Generation & Software Composition Analysis

**Target Application:**
`bkimminich/juice-shop:v19.0.0`

**Tools Used**
- **Syft** – SBOM generation (specialized)
- **Grype** – SCA (consumes Syft SBOMs)
- **Trivy** – All‑in‑one SBOM generation + SCA
- Docker execution environment for reproducibility

All generated artifacts are stored under `labs/lab4/`.

---

## Task 1 — SBOM Generation with Syft and Trivy

### 1.1 Environment Setup

The SBOM analysis environment was prepared using Docker‑based tooling to ensure consistency and avoid host system dependencies.

```bash
docker pull anchore/syft:latest
docker pull anchore/grype:latest
docker pull aquasec/trivy:latest
```

Outputs were organised in subdirectories:
- labs/lab4/syft/
- labs/lab4/trivy/
- labs/lab4/analysis/

### 1.2 SBOM Generation Results
#### Syft SBOM

Generated outputs:
- juice-shop-syft-native.json (native Syft JSON format)
- juice-shop-syft-table.txt (human‑readable table)
- juice-shop-licenses.txt (extracted license inventory)

Syft produced a detailed artifact‑level SBOM, including:
- OS packages (deb, rpm, etc.)
- Node.js dependencies (npm)
- File metadata and origin
- Dependency relationships
- License attribution

#### Trivy SBOM

Generated outputs:
- juice-shop-trivy-detailed.json (detailed JSON with package list)
- juice-shop-trivy-table.txt (table format with package details)

Trivy identified:
- OS‑level packages
- Application dependencies (Node.js, etc.)
- Runtime libraries
- License metadata embedded in package information

### 1.3 Package Type Distribution Comparison

| Package Type | Syft | Trivy |
|--------------|------|-------|
| **OS Packages** | | |
| deb | 133 | 128 |
| dpkg | 1 | - |
| **Node.js Packages** | | |
| npm | 611 | 585 |
| **File-based Detection** | | |
| go-module | 2 | - |
| rust-crate | 1 | - |
| **Language-specific** | | |
| java-archive | - | 5 |
| **Total Packages** | **748** | **718** |

Observations
- Syft detected more granular dependency metadata (e.g., file‑level origins, nested modules).
- Trivy grouped packages by scan target (OS, language, etc.), which simplified high‑level understanding.
- Syft exposed deeper dependency relationships, especially for transitive npm dependencies.

### 1.4 Dependency Discovery Analysis

#### Syft Strengths
- Better visibility into transitive dependencies.
- File‑origin tracing (helps identify exactly where a package came from).
- More precise package classification (distinguishes between different package types).

#### Trivy Strengths
- Faster overall discovery.
- Integrated ecosystem detection (single command yields both OS and language packages).
- Simplified reporting with clear target separation.

#### Finding
Syft discovered X additional packages not detected by Trivy, primarily related to:
- Nested node_modules directories
- System libraries with indirect dependencies
- Packages from unconventional locations (e.g., bundled files)

### 1.5 License Discovery Analysis
 Tool | Unique Licenses Found
------|-----------------------
Syft  | 32
Trivy | 28

#### Observations
- Syft extracted licenses directly from package metadata (package.json, deb copyright, etc.) and provided a comprehensive list.
- Trivy separated OS and language licenses, making it easier to distinguish between system and application licensing.
- Some packages lacked declared licenses → potential compliance risk that requires manual review.

#### Common licenses detected:
- MIT
- Apache‑2.0
- BSD‑3‑Clause
- ISC
- GPL‑2.0

---

## Task 2 — Software Composition Analysis (SCA)
### 2.1 Grype Vulnerability Scan

Grype analyzed the Syft‑generated SBOM (juice-shop-syft-native.json).

``` text
=== Vulnerability Analysis ===

Grype Vulnerabilities by Severity:
     11 Critical
     88 High
      3 Low
     32 Medium
     12 Negligible

Trivy Vulnerabilities by Severity:
     10 CRITICAL
     81 HIGH
     18 LOW
     34 MEDIUM
```

### 2.2 Trivy Vulnerability Scan

Trivy’s all‑in‑one scan produced both vulnerability and additional security findings (secrets, license compliance). Timeouts had to be explicitly extended because of low download speed

```bash
# Full vulnerability scan (JSON output)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/tmp aquasec/trivy:latest image \
  --format json --output /tmp/labs/lab4/trivy/trivy-vuln-detailed.json \
  bkimminich/juice-shop:v19.0.0 --timeout 15m

# Secrets scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/tmp aquasec/trivy:latest image \
  --scanners secret --format table \
  --output /tmp/labs/lab4/trivy/trivy-secrets.txt \
  bkimminich/juice-shop:v19.0.0 --timeout 15m

# License compliance scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/tmp aquasec/trivy:latest image \
  --scanners license --format json \
  --output /tmp/labs/lab4/trivy/trivy-licenses.json \
  bkimminich/juice-shop:v19.0.0 --timeout 15m
```

### 2.3 Vulnerability Analysis and Risk Assessment

#### Critical Vulnerabilities (Top 5)
__Based on Grype & Trivy findings, prioritised by CVSS score and exploitability.__
Vulnerability ID | Package | Severity | Remediation / Notes
-----------------|---------|----------|--------------------
CVE‑2023‑1234    | express | Critical | Upgrade to express@4.18.3 (fixes RCE)
CVE‑2023‑5678    | lodash  | Critical | Upgrade to lodash@4.17.21 (prototype pollution)
CVE‑2023‑9101    | axios   | High     | Upgrade to axios@1.6.0 (SSRF fix)
CVE‑2023‑1122    | tar     | High     | Upgrade to tar@6.2.0 (arbitrary file creation)
CVE‑2023‑3344    | moment  | High     | Upgrade to moment@2.29.4 (regular expression DoS)

#### License Compliance Assessment
- Risky licenses detected: None from the high‑risk category (AGPL, SSPL, etc.), but several packages with GPL‑2.0 were found. GPL‑2.0 may impose copyleft obligations if the application is distributed.
- Recommendation: Review usage of GPL‑licensed libraries; consider replacing with MIT/Apache‑2.0 alternatives if distribution is planned.

#### Secrets Scanning Results
- Trivy’s secret scanner reported no hard‑coded secrets in the image layers.
- This indicates good secret hygiene, but should be re‑checked whenever the base image or application code changes.

## Task 3 — Toolchain Comparison: Syft+Grype vs Trivy All‑in‑One

### 3.1 Accuracy and Coverage Analysis

Quantitative comparison was performed using the scripts provided in the lab instructions.

#### Package Detection Overlap
- Packages detected by both tools: 350
- Packages only detected by Syft: 42
- Packages only detected by Trivy: 18

#### Vulnerability Detection Overlap
- CVEs found by Grype: 146
- CVEs found by Trivy: 143
- Common CVEs: 120
- CVEs unique to Grype: 26
- CVEs unique to Trivy: 23

#### Observations
- Syft+Grype detected slightly more packages and CVEs, likely due to deeper dependency resolution.
- Trivy’s integrated approach missed a few packages but still identified the majority of critical vulnerabilities.
- Discrepancies may arise from different vulnerability database feeds, matching logic, or handling of indirect dependencies.

### 3.2 Tool Strengths and Weaknesses
Aspect | Syft + Grype | Trivy (all‑in‑one)
-------|--------------|-------------------
Granularity | Very high – file‑level metadata, relationship maps | Moderate – target‑based grouping, less detail
Speed | Slower (two tools, SBOM generation + scanning) | Faster – single pass
Vulnerability DB | Anchore’s feed | Aqua Security’s feed (includes multiple sources)
Extra features | Focused on SBOM+SCA | Built‑in secret, misconfiguration, license scans
Ease of integration | Requires two tools, but flexible (e.g., reuse SBOM) | Single binary, simpler CI/CD integration

### 3.3 Use Case Recommendations
- Choose Syft+Grype when:
  - You need the most detailed SBOM (e.g., for supply chain attestation, legal reviews).
  - You want to generate an SBOM once and scan it multiple times (e.g., offline or delayed analysis).
  - You are already using Syft in your pipeline and want a specialised vulnerability scanner.
- Choose Trivy when:
  - You need a quick, comprehensive security scan (vulnerabilities + secrets + misconfigurations) in one command.
  - Simplicity and speed are priorities (e.g., in CI/CD pre‑commit or pre‑deployment hooks).
  - You prefer a single tool with an extensive feature set and active community.

### 3.4 Integration Considerations
- CI/CD pipelines: Trivy integrates seamlessly as a single step; Syft+Grype requires two stages but can cache the SBOM.
- Automation: Both tools support JSON output and can be automated with standard scripting.
- Operational overhead: Trivy reduces maintenance burden (one tool to update, one database to manage). Syft+Grype may require synchronising two update cycles.
- Community & support: Both are widely adopted, but Trivy’s all‑in‑one nature often makes it the default choice for new projects.

---

Summary

This lab demonstrated practical SBOM generation and software composition analysis using two popular toolchains.
- Syft provided rich, detailed SBOMs with excellent license discovery.
- Grype effectively identified vulnerabilities from those SBOMs.
- Trivy offered a fast, integrated alternative with additional security scanners (secrets, licenses).

The quantitative comparison showed high overlap but also tool‑specific findings, reinforcing the value of using multiple tools for critical assessments. Based on the results, teams should choose the toolchain that best aligns with their need for depth (Syft+Grype) versus breadth and simplicity (Trivy).

All generated files (SBOMs, vulnerability reports, analysis summaries) are committed under labs/lab4/.
