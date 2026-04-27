#!/usr/bin/env bash
set -euo pipefail

# Lab 12 runner (non-bonus). Assumes:
# - containerd running (rootful)
# - Kata runtime wired as io.containerd.kata.v2
# - nerdctl installed

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
LAB_DIR="${ROOT_DIR}/labs/lab12"

mkdir -p "${LAB_DIR}"/{setup,runc,kata,isolation,bench,analysis}

echo "== Task 1: Verify Kata runtime =="
egrep -c '(vmx|svm)' /proc/cpuinfo | tee "${LAB_DIR}/setup/virt-check.txt"
containerd --version | tee "${LAB_DIR}/setup/containerd-version.txt"
nerdctl --version | tee "${LAB_DIR}/setup/nerdctl-version.txt"
command -v containerd-shim-kata-v2 | tee "${LAB_DIR}/setup/kata-shim-path.txt"
containerd-shim-kata-v2 --version | tee "${LAB_DIR}/setup/kata-installed-version.txt"
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee "${LAB_DIR}/setup/kata-test-run.txt"

echo "== Task 2.1: Run Juice Shop (runc) =="
nerdctl rm -f juice-runc >/dev/null 2>&1 || true
nerdctl run -d --name juice-runc -p 3012:3000 bkimminich/juice-shop:v19.0.0
sleep 10
curl -s -o /dev/null -w "juice-runc: HTTP %{http_code}\n" http://localhost:3012 | tee "${LAB_DIR}/runc/health.txt"

echo "== Task 2.2: Kata containers (short-lived) =="
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee "${LAB_DIR}/kata/test1.txt"
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -r | tee "${LAB_DIR}/kata/kernel.txt"
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee "${LAB_DIR}/kata/cpu.txt"

echo "== Task 2.3: Kernel comparison =="
{
  echo "=== Kernel Version Comparison ==="
  echo -n "Host kernel (runc uses this): "
  uname -r
  echo -n "Kata guest kernel: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 cat /proc/version
} | tee "${LAB_DIR}/analysis/kernel-comparison.txt"

echo "== Task 2.4: CPU model comparison =="
{
  echo "=== CPU Model Comparison ==="
  echo "Host CPU:"
  grep "model name" /proc/cpuinfo | head -1
  echo "Kata VM CPU:"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1"
} | tee "${LAB_DIR}/analysis/cpu-comparison.txt"

echo "== Task 3: Isolation tests =="
{
  echo "=== dmesg Access Test ==="
  echo "Kata VM (separate kernel boot logs):"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 dmesg 2>&1 | head -5
} | tee "${LAB_DIR}/isolation/dmesg.txt"

{
  echo "=== /proc Entries Count ==="
  echo -n "Host: "
  ls /proc | wc -l
  echo -n "Kata VM: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /proc | wc -l"
} | tee "${LAB_DIR}/isolation/proc.txt"

{
  echo "=== Network Interfaces ==="
  echo "Kata VM network:"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 ip addr
} | tee "${LAB_DIR}/isolation/network.txt"

{
  echo "=== Kernel Modules Count ==="
  echo -n "Host kernel modules: "
  ls /sys/module | wc -l
  echo -n "Kata guest kernel modules: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /sys/module 2>/dev/null | wc -l"
} | tee "${LAB_DIR}/isolation/modules.txt"

echo "== Task 4.1: Startup time comparison =="
{
  echo "=== Startup Time Comparison ==="
  echo "runc:"
  (time nerdctl run --rm alpine:3.19 echo "test") 2>&1 | grep real
  echo "Kata:"
  (time nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 echo "test") 2>&1 | grep real
} | tee "${LAB_DIR}/bench/startup.txt"

echo "== Task 4.2: HTTP latency (juice-runc baseline) =="
out="${LAB_DIR}/bench/curl-3012.txt"
: > "$out"
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:3012/ >> "$out"
done
{
  echo "=== HTTP Latency Test (juice-runc) ==="
  echo "Results for port 3012 (juice-runc):"
  min=$(sort -n "$out" | head -1)
  max=$(sort -n "$out" | tail -1)
  awk -v min="$min" -v max="$max" '{s+=$1; n+=1} END {if(n>0) printf "avg=%.4fs min=%.4fs max=%.4fs n=%d\n", s/n, min, max, n}' "$out"
} | tee "${LAB_DIR}/bench/http-latency.txt"

echo "Done. Fill labs/submission12.md using artifacts under labs/lab12/."

