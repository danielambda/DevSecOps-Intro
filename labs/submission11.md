# Lab 11 Submission — Reverse Proxy Hardening

## Student Evidence

### Task 1 — Reverse Proxy Compose Setup

#### Why reverse proxies improve security
- They provide a single ingress point where we can centrally enforce TLS, headers, request filtering, and logging.
- They let us apply defenses (HSTS, header hardening, rate limits, timeouts) without modifying application code.
- They reduce operational drift because controls are managed in one hardened proxy config rather than per app.

#### Why hiding direct app ports reduces attack surface
- It removes direct host-level access to the app container, so attackers must traverse Nginx controls first.
- It prevents bypass of TLS termination and security headers that are added by the proxy.
- It limits exposed services to only what is required (`8080` for redirect and `8443` for HTTPS).

#### Command evidence
```bash
docker compose ps
```

Output:
```text
NAME            IMAGE                           COMMAND                  SERVICE   CREATED         STATUS         PORTS
lab11-juice-1   bkimminich/juice-shop:v19.0.0   "/nodejs/bin/node /j…"   juice     2 minutes ago   Up 2 minutes   3000/tcp
lab11-nginx-1   nginx:stable-alpine             "/docker-entrypoint.…"   nginx     2 minutes ago   Up 2 minutes   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 80/tcp, 0.0.0.0:8443->8443/tcp, [::]:8443->8443/tcp
```

HTTP redirect check:
```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/
```
Observed: `HTTP 308`

---

### Task 2 — Security Headers

#### Relevant HTTPS headers (`analysis/headers-https.txt`)
```text
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-frame-options: DENY
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
permissions-policy: camera=(), geolocation=(), microphone=()
cross-origin-opener-policy: same-origin
cross-origin-resource-policy: same-origin
content-security-policy-report-only: default-src 'self'; img-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'
```

#### What each header protects against
- **X-Frame-Options**: Blocks clickjacking by preventing the app from being embedded in attacker-controlled iframes.
- **X-Content-Type-Options**: Prevents MIME sniffing, reducing XSS risk from browsers guessing unsafe content types.
- **Strict-Transport-Security (HSTS)**: Forces browsers to use HTTPS for future requests and blocks SSL-stripping downgrade attempts.
- **Referrer-Policy**: Limits referrer leakage to external origins, reducing accidental disclosure of sensitive URLs.
- **Permissions-Policy**: Disables selected browser features (camera/geolocation/microphone), reducing abuse if a script is compromised.
- **COOP/CORP**: Improves process and resource isolation against cross-origin attacks/data leaks by restricting opener/resource sharing.
- **CSP-Report-Only**: Monitors potentially dangerous script/content sources without breaking app behavior while policy tuning is in progress.

---

### Task 3 — TLS, HSTS, Rate Limiting & Timeouts

#### TLS / testssl summary (`analysis/testssl.txt`)
- **Protocols enabled:** TLS 1.2 and TLS 1.3.
- **Protocols disabled:** SSLv2, SSLv3, TLS 1.0, TLS 1.1.
- **Supported cipher suites identified by scan:**
  - `TLS_AES_256_GCM_SHA384`
  - `TLS_CHACHA20_POLY1305_SHA256`
  - `TLS_AES_128_GCM_SHA256`
  - `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`
  - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
- **Why TLSv1.2+ is required:** TLS 1.0/1.1 are deprecated and weaker against modern attacks; TLS 1.2+ gives stronger cryptography and better security defaults, while TLS 1.3 further reduces downgrade surface and handshake complexity.
- **Warnings/vulnerabilities noted:**
  - Most vulnerability checks returned `not vulnerable (OK)` (Heartbleed, POODLE, SWEET32, FREAK, DROWN, LOGJAM, etc.).
  - Expected localhost dev-certificate findings:
    - `Chain of trust NOT ok (self signed)`
    - `NOT ok -- neither CRL nor OCSP URI provided`
    - `OCSP stapling not offered`
    - `DNS CAA RR not offered`

#### HSTS appears only on HTTPS
- HTTP headers file (`analysis/headers-http.txt`) contains no `Strict-Transport-Security`.
- HTTPS headers file (`analysis/headers-https.txt`) contains:
  - `strict-transport-security: max-age=31536000; includeSubDomains; preload`

This confirms HSTS is only set on the TLS endpoint as recommended.

#### Rate-limit test output (`analysis/rate-limit-test.txt`)
```text
401
401
401
401
401
401
429
429
429
429
429
429
```

Result summary:
- `401`: 6 responses (invalid credentials before throttling threshold)
- `429`: 6 responses (rate limiter actively enforcing threshold)

#### Rate limit configuration explanation
- `rate=10r/m`: baseline allowance of 10 login requests per minute per source IP.
- `burst=5`: allows short spikes (5 extra queued/immediate requests) to reduce false positives for legitimate rapid retries.
- Combined effect: enough tolerance for normal user mistakes while still suppressing brute-force bursts by returning `429`.

#### Timeout configuration and trade-offs
- `client_body_timeout 10s`: drops slow body uploads; mitigates slow POST attacks but may hurt very slow clients.
- `client_header_timeout 10s`: closes slow header sends; helps against slowloris-style behavior with similar slow-client trade-off.
- `proxy_read_timeout 30s`: limits upstream response wait time; reduces hanging connections but can cut off truly long app operations.
- `proxy_send_timeout 30s`: limits time to send request to upstream; protects worker resources but may impact unstable/slow links.

#### Access log evidence of 429 responses (`logs/access.log`)
```text
172.19.0.1 - - [22/Apr/2026:14:22:51 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.18.0" rt=0.000 uct=- urt=-
172.19.0.1 - - [22/Apr/2026:14:22:51 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.18.0" rt=0.000 uct=- urt=-
172.19.0.1 - - [22/Apr/2026:14:22:51 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.18.0" rt=0.000 uct=- urt=-
```

---

## Artifacts Produced Under `labs/lab11/`

- `analysis/compose-ps.txt`
- `analysis/headers-http.txt`
- `analysis/headers-https.txt`
- `analysis/testssl.txt`
- `analysis/rate-limit-test.txt`
- `logs/access.log` (contains 429 evidence)

