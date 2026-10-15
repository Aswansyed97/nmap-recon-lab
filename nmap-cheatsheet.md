# 🔍 Nmap Cheat Sheet

A quick-reference for the flags and commands I use most. Grouped by task.

---

## 🎯 Target Specification

| Command | Description |
|:---|:---|
| `nmap 192.168.1.10` | Scan a single host |
| `nmap 192.168.1.1-50` | Scan an IP range |
| `nmap 192.168.1.0/24` | Scan a whole subnet |
| `nmap -iL targets.txt` | Scan hosts from a file |
| `nmap scanme.nmap.org` | Scan by hostname |

---

## 📡 Host Discovery

| Command | Description |
|:---|:---|
| `nmap -sn 192.168.1.0/24` | Ping sweep (no port scan) |
| `nmap -Pn 192.168.1.10` | Skip discovery, treat as online |
| `nmap -PS22,80,443 <t>` | TCP SYN discovery on ports |
| `nmap -PR 192.168.1.0/24` | ARP discovery (local network) |

---

## 🚪 Port Scanning

| Command | Description |
|:---|:---|
| `nmap -sS <t>` | SYN / stealth scan (needs root) |
| `nmap -sT <t>` | TCP connect scan |
| `nmap -sU <t>` | UDP scan |
| `nmap -p 80,443 <t>` | Specific ports |
| `nmap -p- <t>` | All 65,535 ports |
| `nmap -F <t>` | Fast scan (top 100 ports) |
| `nmap --top-ports 20 <t>` | Top N most common ports |

---

## 🔧 Service, Version & OS

| Command | Description |
|:---|:---|
| `nmap -sV <t>` | Service + version detection |
| `nmap -sV --version-intensity 9 <t>` | Max version accuracy |
| `nmap -O <t>` | OS detection |
| `nmap -A <t>` | Aggressive: `-sV -O -sC` + traceroute |

---

## 📜 NSE (Nmap Scripting Engine)

| Command | Description |
|:---|:---|
| `nmap -sC <t>` | Run default scripts |
| `nmap --script vuln <t>` | Vulnerability scripts |
| `nmap --script http-enum <t>` | Enumerate web dirs |
| `nmap --script smb-os-discovery <t>` | SMB/Windows info |

---

## ⏱️ Timing & Performance

| Flag | Description |
|:---|:---|
| `-T0` → `-T5` | Slowest (stealth) → fastest (insane) |
| `--min-rate 1000` | Minimum packets/sec |
| `-T4` | Common balance of speed + reliability |

---

## 📝 Output

| Command | Description |
|:---|:---|
| `-oN scan.txt` | Normal output |
| `-oX scan.xml` | XML output (for reporting tools) |
| `-oG scan.gnmap` | Grepable output |
| `-oA scan` | All three formats at once |
| `-v` / `-vv` | Verbose / very verbose |

---

## ⚡ Go-To One-Liners

```bash
# Quick full recon of one host
sudo nmap -A -T4 192.168.1.10 -oA full_scan

# Fast "what's alive and what's open" across a subnet
sudo nmap -sS -F 192.168.1.0/24

# Hunt for known vulns
sudo nmap -sV --script vuln 192.168.1.10
```

> ⚠️ **Only scan systems you own or have explicit permission to test.** Unauthorized scanning can be illegal.
