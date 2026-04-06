# Lab 8 Submission — Supply Chain: Signing, Verification, and Attestations

Target image: `bkimminich/juice-shop:v19.0.0` (pushed to local registry `localhost:5000`, referenced by **manifest digest** for all signing and attestation operations).

Cosign used: **v3.0.5** (see `labs/lab8/analysis/cosign-version.txt`). The lab instructions target Cosign v2-style `--tlog-upload=false` on its own; on v3 the default Sigstore signing configuration conflicts with that flag, so image sign/attest/blob-sign used **`--use-signing-config=false`** in addition to the lab’s insecure-registry and transparency-log settings.

---

## Task 1 — Local Registry, Signing, Verification, and Tamper Demo

### What I did

1. Ran a local Docker Distribution registry on `localhost:5000` and pushed Juice Shop as `localhost:5000/juice-shop:v19.0.0`.
2. Resolved the **Docker-Content-Digest** for that tag and pinned all crypto to that digest (`labs/lab8/analysis/ref.txt`).
3. Generated a Cosign key pair under `labs/lab8/signing/` (private key is **not** committed; see `labs/lab8/.gitignore`).
4. Signed the digest reference and verified with the public key.
5. **Tamper demo:** retagged `busybox:latest` as `localhost:5000/juice-shop:v19.0.0` and pushed, so the **tag** now points at a different manifest digest (`labs/lab8/analysis/ref-after-tamper.txt`). Verified Cosign behavior on the new digest vs the original.

### Evidence (logs and references)

| Step | Evidence file |
|------|----------------|
| Registry container | `labs/lab8/registry/registry-container.txt` |
| Pull upstream image | `labs/lab8/registry/pull-juice-shop.txt` |
| Push to local registry | `labs/lab8/registry/push-juice-shop.txt` |
| Digest pin (`REF`) | `labs/lab8/analysis/ref.txt`, `labs/lab8/analysis/ref.value` |
| Key generation | `labs/lab8/signing/generate-key-pair.log` |
| Sign | `labs/lab8/signing/cosign-sign.txt` |
| Verify (success) | `labs/lab8/signing/cosign-verify.txt` |
| Pull/tag busybox | `labs/lab8/analysis/pull-busybox.txt`, `labs/lab8/analysis/push-busybox-as-juice-shop.txt` |
| Digest after tamper | `labs/lab8/analysis/ref-after-tamper.txt`, `labs/lab8/analysis/ref-after.value` |
| Verify **fails** on tampered digest | `labs/lab8/signing/cosign-verify-after-tamper-fail.txt` |
| Verify **still succeeds** on original digest | `labs/lab8/signing/cosign-verify-original-still-ok.txt` |

### How signing protects against tag tampering; what “subject digest” means

- **Tags are mutable pointers.** Anyone who can push to a registry can move `v19.0.0` to a completely different image. Consumers who only trust the tag string can be tricked into pulling malware while believing they chose the same “version.”
- **Signing binds identities to an immutable digest.** Cosign records the **subject** as the image’s **manifest digest** (`docker-manifest-digest` / content digest). That digest is computed over the exact manifest bytes stored in the registry. If a tag is repointed, the digest of the **new** manifest is different; it will not match the digest that was signed unless you also re-sign.
- **Observed behavior:** After the tag was overwritten with BusyBox, `cosign verify` against the **new** digest reported **no signatures found** (nothing was signed for that content). Verification against the **original signed digest** still **passed**, which is why production workflows pin **digests**, not tags.

---

## Task 2 — Attestations (SBOM + Provenance)

### SBOM pipeline

1. Generated a Syft SBOM for the digest-pinned reference (Syft-native JSON written under `labs/lab4/syft/` per the lab instructions; log: `labs/lab8/attest/syft-generate.log`).
2. Converted to CycloneDX JSON: `labs/lab8/attest/juice-shop.cdx.json` (log: `labs/lab8/attest/syft-convert-cyclonedx.log`).
3. Attached it as a **CycloneDX** attestation (`labs/lab8/attest/cosign-attest-sbom.log`).
4. Verified the attestation; summarized the in-toto payload with `jq` in `labs/lab8/attest/verify-sbom-attestation-jq.txt` (verification banner: `labs/lab8/attest/verify-sbom-attestation.txt`). Raw `cosign verify-attestation` JSON embeds the entire BOM and is multi‑MB, so the repo keeps the **trimmed jq view** as the inspection artifact.
5. On-disk CycloneDX inspection with `jq`: `labs/lab8/attest/sbom-cdx-inspect-jq.txt`.

### Provenance (minimal demo predicate)

- Predicate file: `labs/lab8/attest/provenance.json`
- Attach log: `labs/lab8/attest/cosign-attest-provenance.log`
- Verify + decode: `labs/lab8/attest/verify-provenance.txt`, `labs/lab8/attest/verify-provenance-jq.txt`

### Attestations vs signatures

- A **signature** answers: “Did a trusted key vouch for **this exact image digest**?”
- An **attestation** answers: “What **additional structured claims** (predicate) about that digest were signed—e.g. SBOM, build provenance, vulnerability report?” It is still a signed object, but wrapped as an in-toto **statement** linking **subject digest + predicate type + payload**.

### What the SBOM attestation contains

From the verified statement (see `verify-sbom-attestation-jq.txt`):

- **in-toto subject:** registry/repo name plus **sha256** digest (the same image content the SBOM was built for).
- **Predicate type:** CycloneDX BOM (`https://cyclonedx.org/bom`).
- **Predicate body:** CycloneDX metadata (e.g. container component, timestamps, Syft as tool) and a **large component graph** (dependencies with versions, licenses, purls/cpes, Syft properties, etc.). In this run the graph has **3533** components.

### What provenance attestations provide

Provenance documents **how and when** something was produced: builder identity, build type, parameters (here: the pinned image reference), and timestamps/completeness hints (`verify-provenance-jq.txt`). In real pipelines (SLSA, build systems), that supports auditing “who built this, from what sources, with what steps?”—a different but complementary question than “what packages are inside?” from an SBOM.

---

## Task 3 — Artifact (Blob) Signing

### Commands and evidence

- Artifact: `labs/lab8/artifacts/sample.txt` → tarball `labs/lab8/artifacts/sample.tar.gz`
- Sign (Sigstore bundle): `labs/lab8/artifacts/sign-blob-bundle.log`, bundle `labs/lab8/artifacts/sample.tar.gz.bundle`
- Verify: `labs/lab8/artifacts/verify-blob.txt`

**Environment note:** `cosign verify-blob` attempted to create `~/.sigstore` under default `COSIGN_HOME`; in this workspace that path was not writable. Setting `COSIGN_HOME` to `labs/lab8/cosign-home` (ignored by git) fixed verification while still using the lab’s key material.

### Use cases for signing non-container artifacts

- **Release binaries** (CLI tools, firmware), **SBOM/policy bundles**, **configuration baselines**, **ML models**, or any file shipped outside an OCI registry—where consumers need integrity + publisher authenticity without an image manifest.

### Blob signing vs image signing

- **Image signing** targets an **OCI image / manifest digest** stored in a registry; signatures and attestations live as **OCI artifacts** associated with that image.
- **Blob signing** targets **arbitrary bytes** (a file). Verification is directly over the file content (here via a **Sigstore bundle**), with no registry manifest involved—though you often **publish** the blob + bundle side by side (e.g. GitHub release assets).

---

## Checklist (PR description)

```text
- [x] Task 1 — Local registry, signing, verification (+ tamper demo)
- [x] Task 2 — Attestations (SBOM or provenance) + payload inspection
- [x] Task 3 — Artifact signing (blob/tarball)
```
