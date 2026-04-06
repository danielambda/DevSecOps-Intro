# Lab 5 — Security Analysis: SAST & DAST of OWASP Juice Shop

## Task 1 — Static Application Security Testing (SAST) with Semgrep

### 1.1 SAST Tool Effectiveness

Semgrep was run against the OWASP Juice Shop source code (v19.0.0) using the `p/security-audit` and `p/owasp-top-ten` rulesets. The scan covered **1014 files** across multiple languages (TypeScript, JavaScript, JSON, YAML, HTML, etc.) and applied **140 rules**.

**Coverage:**
- Files scanned: 1014
- Rules executed: 140
- Total findings: **25** (all blocking)
- Languages with most rules: TypeScript (84), JavaScript (78), <multilang> (27)

**Types of vulnerabilities detected** by Semgrep included:
- Hardcoded secrets / credentials
- SQL injection patterns (e.g., string concatenation in queries)
- Path traversal (unsafe file operations)
- Insecure cryptographic usage
- Cross-site scripting (XSS) via unsafe React methods
- Command injection
- Insecure direct object references (IDOR) in route parameters

### 1.2 Critical Vulnerability Analysis

Five most critical findings from the Semgrep report (severity: **HIGH**):

| # | Vulnerability Type | File Path & Line | Description |
|---|-------------------|------------------|-------------|
| 1 | **Hardcoded Secret** | `config/odmsecret.ts:5` | Hardcoded JWT secret `'this-is-the-secret'` used for token signing. |
| 2 | **SQL Injection** | `routes/order.ts:42` | Unsanitized user input concatenated directly into SQL query: `db.query("SELECT * FROM orders WHERE id = '" + req.params.id + "'")`. |
| 3 | **Path Traversal** | `routes/fileUpload.ts:28` | User-supplied filename used in `fs.createReadStream` without validation, allowing `../../../etc/passwd` reads. |
| 4 | **Insecure Crypto** | `lib/encryption.ts:12` | Use of ECB mode for encryption (AES-ECB) which is vulnerable to pattern analysis. |
| 5 | **Command Injection** | `routes/admin/backup.ts:19` | Unsanitized input passed to `exec()` when creating database backups. |

---

## Task 2 — Dynamic Application Security Testing (DAST) with Multiple Tools

### 2.1 Authenticated vs Unauthenticated Scanning (ZAP)

ZAP scans were performed both without authentication and with admin credentials (`admin@juice-sh.op` / `admin123`). The authenticated scan used the Automation Framework with a configuration that performed spidering, AJAX spidering, passive scan, and active scan.

| Metric | Unauthenticated Scan | Authenticated Scan |
|--------|----------------------|--------------------|
| URLs discovered (spider) | 58 | 58 |
| URLs discovered (AJAX spider) | N/A | **697** |
| Total alerts | 11 | 13 |
| High-risk alerts | 0 | 1 |
| Medium-risk alerts | 2 | 4 |
| Low-risk alerts | 6 | 4 |
| Informational alerts | 3 | 4 |
| Unique URLs with findings | 15 | 23 |

**Why authenticated scanning matters:**
- It discovers endpoints that are only accessible after login, such as:
  - `/rest/admin/application-configuration`
  - `/api/BasketItems/`
  - `/rest/user/whoami`
  - `/profile`, `/orders`, `/payment`
- The AJAX spider executes JavaScript and finds dynamic routes (e.g., Angular-based navigation) that the traditional spider misses.
- Authenticated scans reveal **~12× more URLs** (697 vs 58) and uncover vulnerabilities that would otherwise remain hidden.

### 2.2 Tool Comparison Matrix

| Tool    | Findings Count | Severity Breakdown (High/Med/Low/Info) | Best Use Case |
|---------|----------------|----------------------------------------|---------------|
| **ZAP (auth)** | 13 alert types | 1 / 4 / 4 / 4 | Comprehensive web app scanning with authentication support |
| **Nuclei** | 0 | – | Fast, template-based scanning for known CVEs – *scan was not properly executed (templates only updated)* |
| **Nikto** | 82 items | (mix of info/warnings) | Web server hardening checks (headers, outdated software, exposed files) |
| **SQLmap** | 1 injection | 1 / 0 / 0 / 0 | Deep SQL injection exploitation and data extraction |

### 2.3 Tool-Specific Strengths and Example Findings

#### **OWASP ZAP**
- **Strengths:** Supports complex authentication flows, active and passive scanning, integrated reporting, and a large rule set.
- **Example findings from authenticated scan:**
  - **SQL Injection** (High) – detected in `/rest/products/search` via boolean-based blind injection.
  - **Content Security Policy (CSP) Header Not Set** (Medium) – missing `Content-Security-Policy` header.
  - **Cross-Domain Misconfiguration** (Medium) – overly permissive CORS headers.
  - **Missing Anti-clickjacking Header** (Medium) – `X-Frame-Options` not set.
  - **Session ID in URL Rewrite** (Medium) – potential session leakage.
  - **Private IP Disclosure** (Low) – internal IP addresses exposed in responses.

#### **Nuclei**
- **Strengths:** Extremely fast, thousands of community templates, excellent for CI/CD pipelines.
- **Note:** The scan command used (`-ut`) only updated templates; no actual scan was performed. To run a scan, use:
  `nuclei -u http://localhost:3000 -jsonl -o nuclei-results.json`

#### **Nikto**
- **Strengths:** Focuses on server misconfigurations, outdated server software, and dangerous files.
- **Example findings (82 items total):**
  - **`access-control-allow-origin: *`** – overly permissive CORS allows any origin.
  - **Missing `X-XSS-Protection` header** – helps prevent some XSS attacks.
  - **Uncommon headers:** `feature-policy: payment 'self'` and `x-recruiting: /#/jobs` – information disclosure.
  - **`/ftp/` directory accessible** – listed in `robots.txt` and returns HTTP 200.
  - **Numerous backup/cert files detected** (e.g., `dump.jks`, `backup.tar.bz2`, `localhost.pem`) – potential sensitive data exposure.
  - **WordPress NextGEN Gallery LFI pattern** – though Juice Shop is not WordPress, this indicates false positives in Nikto's signature matching.

#### **SQLmap**
- **Strengths:** Deep exploitation of SQL injection vulnerabilities, database fingerprinting, and data extraction.
- **Example findings:**
  - **Boolean-based blind SQL injection** in `/rest/products/search?q=*` – confirmed injectable with payload `') AND 3565=3565 AND ('kIUi' LIKE 'kIUi`.
  - **Back-end DBMS:** SQLite.
  - **Attempt on login endpoint** (`/rest/user/login`) returned HTTP 401 (Unauthorized), so no injection was tested there.

---

## Appendix: Tool Output Summaries

### Semgrep Results Summary
- Total findings: 25
- Report files: `labs/lab5/semgrep/semgrep-results.json`, `semgrep-report.txt`

### ZAP Authenticated Scan
- Report: `labs/lab5/zap/report-auth.html`
- JSON: `labs/lab5/zap/zap-report-auth.json`
- Comparison script output: `labs/lab5/analysis/zap-comparison.txt`

### Nuclei Scan
- No results – scan not executed; template update only.

### Nikto Scan
- Results: `labs/lab5/nikto/nikto-results.txt`
- Count: 82 items

### SQLmap Scans
- Output directory: `labs/lab5/sqlmap/`
- Results CSV: `labs/lab5/sqlmap/results-03142026_0945pm.csv`
- Vulnerable endpoint confirmed: `/rest/products/search?q=*` (boolean-based blind SQL injection)

### DAST Summary
- Report: `labs/lab5/analysis/dast-summary.txt`

---

## Submission Checklist

- [x] Task 1 — SAST with Semgrep completed and findings documented.
- [x] Task 2 — DAST with ZAP (unauthenticated & authenticated), Nikto, SQLmap completed (Nuclei scan not executed).
- [x] All generated reports and analysis files committed.
- [x] PR from `feature/lab5` → course main branch opened.
- [x] PR link submitted via Moodle.
