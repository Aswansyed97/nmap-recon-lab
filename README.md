# Nmap Recon Lab

Notes, commands, and real scan output from practicing network reconnaissance with Nmap. Recon is the first thing you do in a pentest or when investigating a host: find what is alive, what ports are open, what is running on them, and what the OS is. I kept my commands and findings here as I worked through it on two different targets.

> I only scan machines I own or have permission to test. Everything here is against my own lab: a Metasploitable 2 VM and a TryHackMe practice box. The IPs are internal lab addresses (10.x / 192.168.x), so they mean nothing outside my network.

## Targets

I ran everything against two very different machines on purpose, so I could see how the same scans behave on a locked-down host vs a wide-open one.

| Target | OS | Notes |
|--------|-----|-------|
| TryHackMe box (`10.49.140.148`) | Windows Server (AD) | Firewalled, domain controller, ports come back *filtered* |
| Metasploitable 2 (`192.168.64.13`) | Linux | Intentionally vulnerable, no firewall, ports come back *closed* |

The difference between those two taught me more than any single scan did (see [Filtered vs closed](#filtered-vs-closed-vs-open) below).

## How I work through a target

1. Find live hosts (ARP on the LAN, or `-sn`)
2. Scan ports (`-sS` or `-sT`)
3. Figure out services and versions (`-sV`)
4. Run scripts for extra detail (`-sC`, `--script`)
5. Detect the OS (`-O` / `-A`) if I need it
6. Save the output (`-oA`)

---

## Host discovery

Before scanning ports, find out which hosts are even alive.

### ARP discovery (local network)

On a local network, ARP is the fastest and most reliable way to find hosts. It works at Layer 2 (MAC addresses), so a host firewall cannot block it. The catch: it only works on your own subnet, because routers do not forward ARP.

```bash
sudo netdiscover -i eth0 -f -r 192.168.64.0/24
```

| Flag | Meaning |
|------|---------|
| `-i eth0` | network interface to use |
| `-f` | fast mode |
| `-r` | range to scan |

![netdiscover ARP results](screenshots/15-netdiscover-arp.png)

It found the gateway (`.1`) and my Metasploitable box (`.13`). "Unknown vendor" shows up because VM MAC addresses are randomly generated, so they do not match a real hardware vendor.

### Ping scan with Nmap

```bash
nmap -sn 10.49.140.148        # single host, is it up?
nmap -sn 192.168.64.0/24      # whole subnet
```

`-sn` means "ping scan, skip the port scan." The output is tiny on purpose: it only tells you a host is up, nothing else. (The old name for this was `-sP`, which still works but is deprecated.)

![subnet ping sweep](screenshots/03-ping-sweep-subnet.png)

---

## Scan types

### SYN scan `-sS` (half-open / stealth)

My default. It sends a SYN, and if it gets SYN-ACK back the port is open, then it sends **RST** to tear the connection down instead of finishing the handshake. Because the connection never fully completes, it is faster and quieter than a full connect. It needs root.

```bash
sudo nmap -sS -p- -v 10.49.140.148
```

### TCP connect scan `-sT` (full connect)

Completes the **full** three-way handshake (SYN, SYN-ACK, ACK). It does not need root because it uses the operating system's normal `connect()` call, but it is louder, because the completed connections get logged by the target.

```bash
sudo nmap -sT -p- -v 10.49.140.148
```

![connect scan result](screenshots/08-connect-full-port-result.png)

**The difference, proven by the packet counts:** I ran both as full `-p-` scans against the same box.

| Scan | Raw packets sent | Time | Why |
|------|------------------|------|-----|
| `-sS` | 131,239 | 295s | Nmap crafts every packet itself |
| `-sT` | 4 | 845s | The OS does the connecting, so Nmap sends almost nothing |

Same open ports found, completely different method under the hood.

### UDP scan `-sU`

Everything above is TCP. Plenty of important services run on **UDP**: DNS (53), SNMP (161), DHCP (67), NTP (123). A TCP-only scan misses all of them.

UDP is slow for a reason: TCP gives clear answers (SYN-ACK = open, RST = closed), but UDP is connectionless, so an open port often just stays silent and Nmap has to wait out a timeout on every port. The right way is to limit it:

```bash
sudo nmap -sU --top-ports 20 192.168.64.13
```

**What NOT to do** (I tried it so you can see why):

```bash
sudo nmap -sU -v -p- 192.168.64.13 --min-rate 10000
```

See [`outputs/udp-full-minrate.txt`](outputs/udp-full-minrate.txt). Forcing 10,000 packets/sec at all 65,535 UDP ports made it finish in 13 seconds, but the result was useless: `65529 open|filtered (no-response)` and `11 out of 17 dropped probes`. UDP needs to wait for replies, so rushing it just drops the probes and you learn nothing. Lesson: `--min-rate` speeds up *sending*, not *waiting*, so it is wrong for UDP.

---

## Port selection

By default Nmap scans the top 1000 ports. You control that with `-p`.

| Syntax | Meaning |
|--------|---------|
| `-p 80` | one port |
| `-p 22,23,25,443` | a list |
| `-p 1-1000` | a range |
| `-p-` | all 65,535 ports |

TCP ports run from **0 to 65535** (a 16-bit field, so 65,536 total; 1 to 65535 are scannable). Three zones worth knowing:

| Range | Name | Examples |
|-------|------|----------|
| 0 to 1023 | Well-known | 22 SSH, 80 HTTP, 443 HTTPS, 445 SMB |
| 1024 to 49151 | Registered | 3389 RDP, 3306 MySQL |
| 49152 to 65535 | Dynamic / ephemeral | temporary ports the OS uses for outbound connections |

**Why `-p-` matters:** my quick top-1000 scan missed services hiding on high ports. The full `-p-` scan caught `9389` (AD Web Services) and a batch of `49xxx` RPC dynamic ports that a top-1000 scan never sees.

![full SYN scan result](screenshots/06-syn-full-port-result.png)

**Targeted scan is the fast follow-up.** Once I knew which ports were open, I version-scanned only those:

```bash
nmap -sS -sV -p 22,23,25,443 -v 192.168.64.13
```

That finished in under a second, vs over two minutes for the full scan. Full scan to discover, targeted scan to dig in.

![targeted port scan](screenshots/10-targeted-ports.png)

---

## Service, version, and OS detection

### Version detection `-sV`

After finding open ports, `-sV` sends probes to each one and matches the responses against Nmap's service-fingerprint database to identify the service and its version.

```bash
nmap -sS -sV -p- 192.168.64.13
```

Knowing the version is the bridge from recon to attack: an open port tells you a door exists, but a version like `vsftpd 2.3.4` tells you which known exploits might work.

![Metasploitable full version scan](screenshots/09-metasploitable-full-version.png)

### Default scripts `-sC`

`-sC` runs Nmap's default set of NSE (Nmap Scripting Engine) scripts. Where `-sV` tells you *what version* is running, `-sC` digs for *interesting details*: anonymous FTP logins, SMB shares, SSL cert info, HTTP titles, common misconfigurations.

Full output in [`outputs/metasploitable-full-sV-sC.txt`](outputs/metasploitable-full-sV-sC.txt). A few things the scripts surfaced on Metasploitable:

| Finding | Why it matters |
|---------|----------------|
| `ftp-anon: Anonymous FTP login allowed` | log in with no password |
| SMB `message_signing: disabled (dangerous, but default)` | exposed to relay / MITM |
| `SSLv2 supported` + export ciphers | ancient broken crypto |
| `smb-os-discovery` → hostname, domain, OS | free recon for an attacker |

### OS detection `-O` and aggressive `-A`

`-A` is the "give me everything" scan: it bundles `-sV`, `-O`, `-sC`, and traceroute all together. (So `-A -O` is redundant, `-A` already includes `-O`.)

```bash
sudo nmap -A -p 22,23,25,139,445 192.168.64.13
```

![aggressive + OS detection](screenshots/13-aggressive-os-T2.png)

Worth knowing: OS detection is a **best guess, not a fact**. The output said `97% Linux 2.6.x` but also `No exact OS matches`. It works by sending odd / malformed packets and fingerprinting how the OS responds.

---

## Timing and stealth

Scanning is not just "go fast." It is about matching your noise level to the situation.

| Template | Speed | Use |
|----------|-------|-----|
| `-T0` / `-T1` | slowest | evade detection |
| `-T2` | slow (polite) | gentle |
| `-T3` | default | normal |
| `-T4` | fast | labs, CTFs |
| `-T5` | fastest (insane) | fast networks only |

Higher number = faster (and louder). I mixed this up at first and thought `-T2` sped things up, it actually slows them down. `--min-rate 10000` forces a minimum packet rate and is the fastest / loudest option, fine in a lab but it floods the target and trips intrusion-detection systems in the real world.

### Why aggressive scans are loud

`-A` and especially `-O` are the most detectable things you can run. OS detection sends weird packets (illegal flag combinations, probes to closed ports) that normal traffic never produces, so an IDS flags it instantly. On fragile devices those odd probes can even crash the service. In the real world you stay quiet and only pull out `-A` when stealth does not matter.

### Evasion techniques

```bash
sudo nmap -A -f -v --data-length 5 -p 22,23,25,139,445 192.168.64.13 -T2
```

Full output in [`outputs/evasion-fragment-datalength.txt`](outputs/evasion-fragment-datalength.txt).

| Flag | Trick |
|------|-------|
| `-f` | fragment packets into tiny pieces so some firewalls cannot inspect them |
| `--data-length 5` | add random bytes so the packet size no longer matches Nmap's known signature |
| `-T2` | go slow to stay under rate-based detection |

Honest note: these worked great years ago. Modern firewalls reassemble fragments and are not fooled by a few extra bytes, so `-f` and `--data-length` are mostly defeated by current gear. Still worth knowing for old targets and CTFs. Related flags in the same family: `-D` (decoys), `--source-port`, `-S` (spoof source IP).

---

## Saving output `-oA`

```bash
nmap -sS -sV -p 22,23,25,443 -v 192.168.64.13 -oA meta
```

`-oA` saves all three output formats at once from one base name:

| File | Format | Use |
|------|--------|-----|
| `meta.nmap` | normal / readable | read it later |
| `meta.xml` | XML | feed into other tools |
| `meta.gnmap` | grepable | `grep open meta.gnmap` |

(Individually: `-oN` normal, `-oX` XML, `-oG` grepable.) Saving output is a good habit, you do not want to re-run a 10-minute scan because you lost the terminal.

![oA output files](screenshots/12-oA-files.png)

---

## Banner grabbing

A banner is the greeting a service sends when you connect. Connect to FTP and it literally says `220 (vsFTPd 2.3.4)`. Grabbing banners by hand is the manual version of what `-sV` automates, doing it myself helped me understand where version info actually comes from.

```bash
nmap -sV --script=banner 192.168.64.13 -v
```

Full output in [`outputs/banner-grab.txt`](outputs/banner-grab.txt). Some of what the services announced:

| Port | Banner | Reveals |
|------|--------|---------|
| 21 | `220 (vsFTPd 2.3.4)` | FTP version |
| 22 | `SSH-2.0-OpenSSH_4.7p1 Debian` | SSH version |
| 25 | `220 metasploitable.localdomain ESMTP Postfix` | mail server + hostname |
| 1524 | `root@metasploitable:/#` | a root shell, wide open |

That port 1524 banner is a root command prompt advertising itself. The service told me it was a backdoor just by me reading its greeting.

---

## Filtered vs closed vs open

This was the single most useful thing I learned, and it is why I scanned two different machines.

| State | What it means | What you see |
|-------|---------------|--------------|
| **open** | service is listening | SYN-ACK reply |
| **closed** | nothing listening, but host reachable | RST reply |
| **filtered** | a firewall is silently dropping packets | no response |

The TryHackMe Windows box came back with ports **filtered** (firewall dropping packets), which is *also* useful information: it tells you a firewall is there. Metasploitable came back **closed** on unused ports (no firewall, so it actively replies with RST).

That one difference explains everything else I saw:

| | TryHackMe (Windows, firewalled) | Metasploitable (Linux, no firewall) |
|---|---|---|
| Unused ports | filtered (no-response) | closed (reset) |
| Full `-p-` scan speed | slow (waits on timeouts) | fast (instant RST replies) |
| `-sV` output | limited | rich, old versions everywhere |

A firewalled host makes Nmap wait out a timeout on every dead port, which is why those scans crawled. The open host answers instantly, so the same scan finished in seconds.

---

## Repo structure

```
nmap-recon-lab/
├── README.md
├── nmap-cheatsheet.md          full flag reference
├── scripts/
│   └── recon.sh                staged recon script
├── outputs/                    raw scan output (text)
│   ├── metasploitable-full-sV-sC.txt
│   ├── banner-grab.txt
│   ├── evasion-fragment-datalength.txt
│   └── udp-full-minrate.txt
└── screenshots/                scan screenshots + wireshark/
```

## TCP three-way handshake (Wireshark)

Since the SYN vs connect scans are all about the handshake, I captured one in Wireshark to see it on the wire.

The handshake is three packets: **SYN → SYN-ACK → ACK**. Each side picks its own random starting sequence number (the ISN, randomized so an attacker cannot predict it and hijack the session).

![SYN packet flags](screenshots/wireshark/01-tcp-syn-flags.png)

The first packet has only the SYN flag set (`0x002`), nothing else:

| Packet | Flags | Raw Seq | Raw Ack | Meaning |
|--------|-------|---------|---------|---------|
| 1. SYN | SYN | 4132337077 | 0 | "here is my starting number" |
| 2. SYN-ACK | SYN+ACK | 55616001 | 4132337078 | "here is mine, and I ack yours + 1" |
| 3. ACK | ACK | 4132337078 | 55616002 | "I ack your number + 1" |

The key thing I got wrong at first: the **+1 happens in the ACK number, not the sequence number**. Each side has its own independent counter, and the +1 is each side confirming it received the other's SYN.

![raw sequence number](screenshots/wireshark/02-syn-raw-seq.png)
![SYN-ACK raw ack](screenshots/wireshark/03-synack-raw-ack.png)
![final ACK raw](screenshots/wireshark/04-ack-raw.png)

My own diagram of the three packets and their sequence numbers:

![handshake diagram](screenshots/wireshark/05-handshake-diagram.png)

This connects straight back to the scans: `-sT` completes this full handshake, while `-sS` cuts it off with RST after the SYN-ACK, which is why it is called half-open.

---

Built by Aswan Syed. [LinkedIn](https://www.linkedin.com/in/aswan-syed-3154703b4)
