# Lab 6 — Infrastructure-as-Code Security: Scanning & Policy Enforcement

## Overview

This lab focuses on performing security analysis on Infrastructure-as-Code (IaC) configurations using multiple scanning tools. The goal is to identify security misconfigurations and vulnerabilities in **Terraform**, **Pulumi**, and **Ansible** infrastructure code.

The following tools were used during the analysis:

* **tfsec** – Terraform-specific security scanner
* **Checkov** – policy-as-code IaC security scanner
* **Terrascan** – OPA-based compliance and security scanner
* **KICS (Checkmarx)** – multi-framework IaC scanner used for Pulumi and Ansible

The intentionally vulnerable infrastructure code contained over 80 security issues across all frameworks.

---

# Task 1 — Terraform & Pulumi Security Scanning

## Terraform Tool Comparison

Three different scanners were used to analyze Terraform configurations.

| Tool      | Findings |
| --------- | -------- |
| tfsec     | 53       |
| Checkov   | 78       |
| Terrascan | 22       |

### Analysis

**Checkov** detected the largest number of issues (78). This is expected because it uses a large policy library covering multiple security domains including compliance policies.

**tfsec** reported 53 issues and focuses specifically on Terraform security best practices. It typically produces fewer false positives and is optimized for fast scanning.

**Terrascan** detected 22 issues. It uses an Open Policy Agent (OPA) based rule engine and focuses strongly on compliance-related policies rather than purely security misconfigurations.

Overall observations:

* **Checkov** provides the most comprehensive coverage.
* **tfsec** is fast and Terraform-specific.
* **Terrascan** is useful for compliance and governance checks.

Using multiple tools together improves overall vulnerability detection.

---

## Pulumi Security Analysis (KICS)

Pulumi infrastructure was scanned using **KICS**, which supports Pulumi YAML manifests and cloud infrastructure resources.

### Pulumi Scan Results

| Severity | Count |
| -------- | ----- |
| CRITICAL | 1     |
| HIGH     | 2     |
| MEDIUM   | 1     |
| INFO     | 2     |
| LOW      | 0     |

**Total Findings:** 6

### Key Vulnerabilities Identified

1. **RDS DB Instance Publicly Accessible (CRITICAL)**
   A database instance was configured with public network access, allowing exposure to the internet.

2. **DynamoDB Table Not Encrypted (HIGH)**
   DynamoDB table storage encryption was disabled, which risks exposure of sensitive data.

3. **Hardcoded Password / Secret (HIGH)**
   Secrets were stored directly in configuration files.

4. **EC2 Instance Monitoring Disabled (MEDIUM)**
   Monitoring was disabled which reduces visibility into instance behavior and potential attacks.

5. **DynamoDB Point-in-Time Recovery Disabled (INFO)**
   Lack of backup configuration increases risk of data loss.

### Terraform vs Pulumi Security Comparison

Terraform uses a **declarative HCL configuration**, while Pulumi allows infrastructure to be written programmatically.

Observations:

| Aspect              | Terraform                         | Pulumi                               |
| ------------------- | --------------------------------- | ------------------------------------ |
| Configuration Style | Declarative (HCL)                 | Programmatic / YAML                  |
| Tool Ecosystem      | Large (tfsec, Checkov, Terrascan) | Smaller                              |
| Security Issues     | Mostly misconfiguration           | Misconfiguration + secret management |

Pulumi configurations may introduce additional risks because they can include **application logic and embedded secrets**.

---

## KICS Pulumi Support

KICS provides a large query catalog specifically designed for cloud resources such as:

* AWS
* Azure
* GCP
* Kubernetes

Advantages of KICS for Pulumi scanning:

* Native support for Pulumi YAML manifests
* Extensive security rule library
* Multi-cloud resource coverage
* Multiple report formats (JSON, HTML, SARIF)

However, Pulumi support is still evolving and may not detect as many issues as Terraform-specific scanners.

---

# Task 2 — Ansible Security Scanning with KICS

## Ansible Scan Results

| Severity | Count |
| -------- | ----- |
| HIGH     | 9     |
| LOW      | 1     |
| MEDIUM   | 0     |
| CRITICAL | 0     |

**Total Findings:** 10

Most vulnerabilities were related to **hardcoded credentials and secret management**.

---

## Key Security Issues

### 1. Passwords in URLs

Passwords were included directly inside URLs.

Example issue:

```
Passwords And Secrets - Password in URL
deploy.yml
```

Security impact:

* Credentials may be exposed in logs
* Passwords may leak via browser history or monitoring tools

Remediation:

Use environment variables or secure credential stores.

---

### 2. Hardcoded Passwords in Playbooks

Multiple passwords were stored directly in configuration files.

Example:

```
Passwords And Secrets - Generic Password
inventory.ini
configure.yml
```

Security impact:

* Credentials stored in plaintext
* High risk of credential leakage

Remediation:

Use **Ansible Vault**:

```bash
ansible-vault encrypt vars.yml
```

---

### 3. Unpinned Package Versions

```
Unpinned Package Version
deploy.yml
```

Security impact:

* Installing latest package versions may introduce breaking changes
* Potentially vulnerable versions could be installed

Remediation:

Specify package versions explicitly.

Example:

```
name: nginx=1.24.0
state: present
```

---

## KICS Ansible Queries

KICS performs security checks in the following areas:

* Secret detection
* Authentication and credential management
* Command execution vulnerabilities
* File permission issues
* Configuration best practices

These checks help enforce secure infrastructure automation practices.

---

# Task 3 — Comparative Tool Analysis & Security Insights

## Tool Comparison Matrix

| Criterion         | tfsec                | Checkov              | Terrascan           | KICS                     |
| ----------------- | -------------------- | -------------------- | ------------------- | ------------------------ |
| Total Findings    | 53                   | 78                   | 22                  | 16                       |
| Scan Speed        | Fast                 | Medium               | Medium              | Medium                   |
| False Positives   | Low                  | Medium               | Medium              | Medium                   |
| Report Quality    | ⭐⭐⭐⭐                 | ⭐⭐⭐⭐                 | ⭐⭐⭐                 | ⭐⭐⭐⭐                     |
| Ease of Use       | ⭐⭐⭐⭐                 | ⭐⭐⭐                  | ⭐⭐⭐                 | ⭐⭐⭐                      |
| Documentation     | ⭐⭐⭐⭐                 | ⭐⭐⭐⭐                 | ⭐⭐⭐                 | ⭐⭐⭐                      |
| Platform Support  | Terraform            | Multi-framework      | Multi-framework     | Multi-framework          |
| Output Formats    | JSON, text           | JSON, CLI, SARIF     | JSON, human         | JSON, HTML               |
| CI/CD Integration | Easy                 | Easy                 | Medium              | Easy                     |
| Unique Strengths  | Fast Terraform scans | Large policy library | Compliance policies | Multi-framework scanning |

---

## Vulnerability Category Analysis

| Security Category  | tfsec | Checkov | Terrascan | KICS (Pulumi) | KICS (Ansible) | Best Tool |
| ------------------ | ----- | ------- | --------- | ------------- | -------------- | --------- |
| Encryption Issues  | ✔     | ✔       | ✔         | ✔             | N/A            | Checkov   |
| Network Security   | ✔     | ✔       | ✔         | ✔             | ✔              | tfsec     |
| Secrets Management | ✔     | ✔       | ✖         | ✔             | ✔              | KICS      |
| IAM / Permissions  | ✔     | ✔       | ✔         | ✔             | ✖              | Checkov   |
| Access Control     | ✔     | ✔       | ✔         | ✔             | ✔              | tfsec     |
| Compliance         | ✔     | ✔       | ✔         | ✔             | ✔              | Terrascan |

---

# Top 5 Critical Findings

## 1. Publicly Accessible RDS Database

Risk:
Database exposed to the internet.

Example insecure configuration:

```
publicly_accessible = true
```

Remediation:

```
publicly_accessible = false
```

---

## 2. Unencrypted DynamoDB Table

Risk:
Sensitive data stored without encryption.

Remediation:

```
server_side_encryption {
  enabled = true
}
```

---

## 3. Hardcoded Credentials

Risk:
Credentials exposed in code repositories.

Remediation:

Use:

* AWS Secrets Manager
* Parameter Store
* Environment variables

---

## 4. Passwords in URLs

Risk:
Credentials exposed in logs.

Remediation:

Use secure variables or secret managers.

---

## 5. Lack of Monitoring on EC2 Instances

Risk:
Reduced visibility into system activity.

Remediation:

Enable monitoring:

```
monitoring = true
```

---

# CI/CD Integration Strategy

For production environments, IaC security scan
