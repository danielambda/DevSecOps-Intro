# Lab 2 — Threat Modeling with Threagile

## Overview

This submission documents the threat modeling of the OWASP Juice Shop (`bkimminich/juice-shop:v19.0.0`) using Threagile.
The lab includes a baseline threat model, a secure HTTPS variant, and a comparative risk analysis demonstrating how security controls affect the risk landscape.

---

## Task 1 — Threagile Baseline Model

### Baseline Model Generation

- Threagile was executed using the provided YAML model:
  - Model file: `lab2/threagile-model.yaml`
  - Output directory: `lab2/baseline/`
- The Docker-based Threagile run successfully generated:
  - `report.pdf`
  - Risk data (`risks.json`, `stats.json`, `technical-assets.json`)
  - Data-flow and asset diagrams (PNG)

### Generated Artifacts

- PDF Report: `lab2/baseline/report.pdf`
- Diagrams:
  - Data Flow Diagram: `lab2/baseline/data-flow-diagram.png`
  - Data Asset Diagram: `lab2/baseline/data-asset-diagram.png`
- Risk Export: `lab2/baseline/risks.json`

---

### Risk Ranking Methodology

Risks were ranked using a composite score calculated as follows:

```
Composite Score = Severity × 100 + Likelihood × 10 + Impact
```

**Scoring values used:**

| Dimension | Values |
|-----------|--------|
| Severity  | critical (5), elevated (4), high (3), medium (2), low (1) |
| Likelihood| very-likely (4), likely (3), possible (2), unlikely (1) |
| Impact    | high (3), medium (2), low (1) |

The Top 5 risks were selected based on the highest composite scores.

---

### Top 5 Risks (Baseline)

| Rank | Risk Title                         | Category                    | Asset       | Severity     | Likelihood  | Impact   | Composite Score |
|-----:|------------------------------------|-----------------------------|-------------|--------------|-------------|----------|-----------------|
| 1    | Unencrypted Communicatin           | unencrypted-communication   | Application | elevated (4) | likely (3)  | high (3) | 433             |
| 2    | Missing Authentication             | missing-authentication      | Application | elevated (4) | likely (3)  | high (3) | 432             |
| 3    | Cross-Site Scripting (XSS)         | cross-site-scripting        | Application | elevated (4) | likely (3)  | high (3) | 432             |
| 4    | Cross-Site Request Forgery (CSRF)  | cross-site-request-forgery  | Application | high (3)     | likely (3)  | high (3) | 241             |
| 5    | Server-Side Request Forgery (SSRF) | server-side-request-forgery | Application | high (3)     | possible (2)| high (3) | 231             |

---

### Baseline Risk Analysis

The baseline threat model highlights several critical application-layer risks. Unencrypted communication represents the highest risk due to the potential for credential leakage and data interception. Authentication-related weaknesses and common web vulnerabilities such as XSS and CSRF further increase the attack surface, particularly in a deliberately vulnerable application like OWASP Juice Shop. SSRF remains a concern due to its potential to access internal resources.

---

## Task 2 — Secure HTTPS Variant & Risk Comparison

### Secure Model Changes

A secure variant of the baseline model was created at: `lab2/threagile-model.secure.yaml`

The following changes were applied:

- Communication between **User Browser → Application** set to `protocol: https`
- Communication involving the **Reverse Proxy** set to `protocol: https`
- **Persistent Storage** configured with `encryption: transparent`

No asset names or architectural structure were changed to ensure accurate risk comparison.

---

### Secure Variant Generation

- Output directory: `lab2/secure/`
- Generated artifacts:
  - `report.pdf`
  - Updated diagrams
  - Updated `risks.json`

---

### Risk Category Delta Table

The following table compares the number of risks per category between the baseline and secure models:

| Category | Baseline | Secure | Δ |
|---|---:|---:|---:|
| container-baseimage-backdooring | 1 | 1 | 0 |
| cross-site-request-forgery | 2 | 2 | 0 |
| cross-site-scripting | 1 | 1 | 0 |
| missing-authentication | 1 | 1 | 0 |
| missing-authentication-second-factor | 2 | 2 | 0 |
| missing-build-infrastructure | 1 | 1 | 0 |
| missing-hardening | 2 | 2 | 0 |
| missing-identity-store | 1 | 1 | 0 |
| missing-vault | 1 | 1 | 0 |
| missing-waf | 1 | 1 | 0 |
| server-side-request-forgery | 2 | 2 | 0 |
| unencrypted-asset | 2 | 1 | -1 |
| unencrypted-communication | 2 | 0 | -2 |
| unnecessary-data-transfer | 2 | 2 | 0 |
| unnecessary-technical-asset | 2 | 2 | 0 |

---

### Delta Analysis

The baseline threat model highlights several critical application-layer risks. Unencrypted communication represents the highest risk due to the potential for credential leakage and data interception. Authentication-related weaknesses and common web vulnerabilities such as XSS and CSRF further increase the attack surface, particularly in a deliberately vulnerable application like OWASP Juice Shop. SSRF remains a concern due to its potential to access internal resources.

---

### Diagram Comparison
- Baseline Diagrams: `lab2/baseline/data-flow-diagram.png`, `lab2/baseline/data-asset-diagram.png`
- Secure Diagram: `lab2/secure/data-flow-diagram.png`, `lab2/baseline/data-asset-diagram.png`

The data-flow diagram reflects the transition to HTTPS, while the data-asset diagram remains unchanged, as encryption at rest does not alter asset relationships.

---

## Conclusion

This lab demonstrates how threat modeling as code enables systematic evaluation of security controls. Introducing HTTPS and encryption at rest significantly reduced transport and storage-related risks while leaving application-layer vulnerabilities unchanged. This highlights the importance of layered defenses and complementary controls when securing web applications.
