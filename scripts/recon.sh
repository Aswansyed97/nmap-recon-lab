#!/usr/bin/env bash
# =============================================================
#  recon.sh — staged Nmap reconnaissance helper
#  Usage: ./recon.sh <target-ip-or-cidr>
#  Example: ./recon.sh 192.168.1.0/24
# =============================================================

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target-ip-or-cidr>"
  exit 1
fi

OUTDIR="scans/$(echo "$TARGET" | tr '/' '_')_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"
echo "[*] Target:  $TARGET"
echo "[*] Output:  $OUTDIR"
echo

# 1. Host discovery -------------------------------------------
echo "[1/4] Host discovery (ping sweep)..."
nmap -sn "$TARGET" -oN "$OUTDIR/01_host_discovery.txt"

# 2. Full TCP port scan ---------------------------------------
echo "[2/4] Full TCP port scan..."
sudo nmap -sS -p- --min-rate 1000 "$TARGET" -oN "$OUTDIR/02_ports.txt"

# 3. Service & version + default scripts ----------------------
echo "[3/4] Service/version detection + default scripts..."
sudo nmap -sV -sC "$TARGET" -oN "$OUTDIR/03_services.txt"

# 4. OS detection ---------------------------------------------
echo "[4/4] OS detection..."
sudo nmap -O "$TARGET" -oN "$OUTDIR/04_os.txt"

echo
echo "[+] Recon complete. Results saved in: $OUTDIR"
