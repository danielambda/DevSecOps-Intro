# Submission 10 — Vulnerability Management & Response with DefectDojo

## Repository / Branch

- Branch: `feature/lab10`
- Lab folder: `labs/lab10/`

## Task 1 — DefectDojo Local Setup Evidence

- Cloned DefectDojo source into `labs/lab10/setup/django-DefectDojo-src`.
- Started the stack with Docker Compose and verified containers were running (`nginx`, `uwsgi`, `celeryworker`, `celerybeat`, `postgres`, `valkey`).
- Access URL confirmed at `http://localhost:8080`.
- Initial admin password generated from initializer logs and used to access the UI.
- Sanitized setup evidence stored in:
  - `labs/lab10/setup/dojo-setup-evidence.txt`

## Task 2 — Multi-Tool Import Results

- Import execution command:
  - `bash labs/lab10/imports/run-imports.sh`
- API context auto-created by importer:
  - Product Type: `Engineering`
  - Product: `Juice Shop`
  - Engagement: `Labs Security Testing`
- Import response artifacts saved in `labs/lab10/imports/`:
  - `import-zap-report-noauth.json.json`
  - `import-semgrep-results.json.json`
  - `import-trivy-vuln-detailed.json.json`
  - `import-grype-vuln-results.json.json`
- Tool-by-tool outcome:
  - ZAP: import attempted but parser expected XML for available `ZAP Scan` test type.
  - Semgrep: import successful, zero findings parsed.
  - Trivy: import successful, 147 findings.
  - Nuclei: skipped because `labs/lab5/nuclei/nuclei-results.json` was not present.
  - Grype: import successful, 122 findings.

## Task 3 — Reporting & Program Metrics

### Generated Artifacts

- Metrics snapshot: `labs/lab10/report/metrics-snapshot.md`
- Human-readable report: `labs/lab10/report/dojo-report.html`
- Findings export CSV: `labs/lab10/report/findings.csv`
- Supporting raw exports:
  - `labs/lab10/report/findings.json`
  - `labs/lab10/report/tests.json`
  - `labs/lab10/report/metrics.json`
  - `labs/lab10/report/per-tool.json`

### Metrics Highlights (Stakeholder Summary)

- Open vs. closed by severity currently shows **269 open / 0 closed** findings, dominated by **High (147)** and **Medium (68)** severities, with **21 Critical**.
- Findings by tool are concentrated in image/package scanners: **Trivy (147)** and **Grype (122)**; Semgrep imported with zero findings; ZAP import requires XML format for this Dojo parser.
- SLA outlook indicates **0 breached items** and **21 findings due within 14 days**, giving a short-term remediation queue without overdue debt.
- The most frequent weakness classes are **CWE-1333**, **CWE-407**, and **CWE-22**, which provides a concrete target list for secure coding and dependency hardening.
- Verification status shows **143 verified findings** and **0 mitigated**, indicating triage has started but remediation closure has not yet begun.
