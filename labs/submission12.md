# Submission 12 — Kata Containers (VM-backed container sandboxing)

## Environment

- **Host OS**: NixOS (Linux)
- **CPU virtualization check**: see `labs/lab12/setup/virt-check.txt`
- **containerd version**: see `labs/lab12/setup/containerd-version.txt`
- **nerdctl version**: see `labs/lab12/setup/nerdctl-version.txt`

---

## Task 1 — Install and Configure Kata

### Shim version

Evidence:
- `labs/lab12/setup/kata-installed-version.txt`

### Kata test run (io.containerd.kata.v2)

Evidence:
- `labs/lab12/setup/kata-test-run.txt`

---

## Task 2 — Run and Compare Containers (runc vs kata)

### runc: Juice Shop health

Evidence:
- `labs/lab12/runc/health.txt` (expect HTTP 200)

### Kata: short-lived containers

Evidence:
- `labs/lab12/kata/test1.txt`
- `labs/lab12/kata/kernel.txt`
- `labs/lab12/kata/cpu.txt`

### Kernel comparison

Evidence:
- `labs/lab12/analysis/kernel-comparison.txt`

Key finding:
- **runc** uses the **host kernel** (matches `uname -r`).
- **Kata** uses a **guest kernel** (KVM/QEMU VM), so `/proc/version` differs and typically shows a Kata-provided kernel.

### CPU model comparison

Evidence:
- `labs/lab12/analysis/cpu-comparison.txt`

Isolation implications:
- **runc**: processes are namespaced but share the host kernel (kernel attack surface is shared).
- **Kata**: VM boundary isolates the kernel; a container escape would first need to break out of the guest, then the hypervisor boundary.

---

## Task 3 — Isolation Tests

### dmesg access

Evidence:
- `labs/lab12/isolation/dmesg.txt`

Expected observation:
- Kata shows VM boot/kernel logs (separate kernel), unlike runc which would reflect the host kernel (or be restricted by permissions).

### /proc visibility

Evidence:
- `labs/lab12/isolation/proc.txt`

Expected observation:
- Kata VM has a different `/proc` landscape (guest kernel), and process visibility differs.

### Network interfaces

Evidence:
- `labs/lab12/isolation/network.txt`

Expected observation:
- Kata VM shows its own virtual NIC(s) inside the guest.

### Kernel modules

Evidence:
- `labs/lab12/isolation/modules.txt`

Expected observation:
- Guest kernel module set differs from the host’s module set.

Security implications:
- **runc escape**: attacker lands on the host kernel boundary; impact can be host compromise.
- **Kata escape**: attacker lands inside guest first; must also break hypervisor boundary to compromise host, raising the bar substantially.

---

## Task 4 — Performance Comparison

### Startup time

Evidence:
- `labs/lab12/bench/startup.txt`

Expected trend:
- **runc** starts near-instantly.
- **Kata** has VM boot/init overhead (seconds).

### HTTP latency baseline (juice-runc)

Evidence:
- `labs/lab12/bench/http-latency.txt`
- raw samples: `labs/lab12/bench/curl-3012.txt`

Tradeoffs summary:
- **Startup overhead**: higher for Kata due to VM.
- **Runtime overhead**: can be modest but varies (I/O, networking, CPU virtualization).
- **Operational overhead**: more moving parts (kernel/rootfs assets, hypervisor, debugging guest).

