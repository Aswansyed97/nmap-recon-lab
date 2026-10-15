# Nmap Recon Lab

Notes and scripts from practicing network reconnaissance with Nmap. This is the first thing you do in a pentest or when investigating a host: figure out what's alive, what ports are open, what's running on them, and what OS it is. I'm keeping my commands and findings here as I work through it.

> Only scan machines you own or have permission to test. For practice I use my own lab VMs and `scanme.nmap.org`, which Nmap puts up specifically for this.

## How I work through a target

1. Find live hosts (`-sn`)
2. Scan ports (`-sS` or `-sT`)
3. Figure out services and versions (`-sV`)
4. Detect the OS (`-O`)
5. Run NSE scripts if something looks interesting (`-sC`, `--script`)
6. Save the output (`-oN`, `-oX`)

## Scan types I use most

| Scan | Flag | Notes |
|------|------|-------|
| Ping sweep | `-sn` | Just find live hosts, no port scan |
| SYN scan | `-sS` | Fast, needs root, my default |
| TCP connect | `-sT` | Works without root, louder |
| UDP scan | `-sU` | Slow but catches DNS/SNMP/DHCP |
| Version detection | `-sV` | Service + version |
| OS detection | `-O` | Needs root |
| Aggressive | `-A` | sV + O + sC + traceroute in one go |

## Commands

Host discovery:
```bash
nmap -sn 192.168.1.0/24
```

Port scanning:
```bash
sudo nmap -sS 192.168.1.10          # top 1000 ports
sudo nmap -p- 192.168.1.10          # all 65535
```

Services and OS:
```bash
nmap -sV 192.168.1.10
sudo nmap -O 192.168.1.10
sudo nmap -A 192.168.1.10           # everything at once
```

Saving output:
```bash
nmap -sV -oN scan.txt -oX scan.xml 192.168.1.10
```

There's a longer reference in [nmap-cheatsheet.md](nmap-cheatsheet.md) and a script that runs the stages in order in [scripts/recon.sh](scripts/recon.sh).

## Stuff that clicked while practicing

- `-sS` doesn't finish the TCP handshake, that's why it's faster and quieter than `-sT`.
- A "filtered" port usually means a firewall is dropping the packet, which tells you something on its own.
- The service version from `-sV` is the useful part. Once you have something like `vsftpd 2.3.4` you can go look up known CVEs for it.
- Save your output. Scrolling back through terminal history to find what a scan said is annoying.

## Screenshots

Adding my own scan output here as I go.

---

Built by Aswan Syed. [LinkedIn](https://www.linkedin.com/in/aswan-syed-3154703b4)
