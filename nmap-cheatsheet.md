# Nmap cheat sheet

The flags and commands I actually use, pulled together so I stop re-googling them. Examples use my lab boxes (`192.168.64.13` is Metasploitable, `10.49.140.148` was the TryHackMe box). `<ip>` just means "put the target here."

## Picking targets

```bash
nmap 192.168.64.13            # one host
nmap 192.168.64.1-50          # a range
nmap 192.168.64.0/24          # the whole subnet
nmap -iL targets.txt          # read targets from a file
```

## Finding live hosts

```bash
nmap -sn 192.168.64.0/24      # ping sweep, no port scan
nmap -PR 192.168.64.0/24      # ARP discovery (local net, can't be firewalled)
nmap -Pn <ip>                 # skip discovery, assume it's up (use when ping is blocked)
```

On a LAN, netdiscover is handy too: `sudo netdiscover -i eth0 -r 192.168.64.0/24`

## Scanning ports

```bash
sudo nmap -sS <ip>            # SYN / half-open, my default (needs root)
nmap -sT <ip>                 # full connect, works without root but louder
sudo nmap -sU --top-ports 20 <ip>   # UDP, keep it small or it takes forever
```

Picking ports:

```bash
nmap -p 80,443 <ip>           # specific ports
nmap -p-  <ip>                # all 65535 (slow, but finds the hidden high ports)
nmap -F <ip>                  # fast, top 100 only
```

Quick notes to self:
- `-sS` never finishes the handshake (sends RST), that's why it's quieter than `-sT`.
- `-p-` is where I found 9389 and the 49xxx RPC ports that the default scan missed.
- Don't throw `--min-rate` at UDP, it just drops the probes and you get "no-response" on everything.

## Service / version / OS

```bash
nmap -sV <ip>                 # what service + version is running
nmap -O <ip>                  # OS guess (it IS a guess, not a fact)
nmap -A <ip>                  # everything: -sV + -O + -sC + traceroute
```

`-A` is loud though. `-O` especially gets flagged by IDS because it sends weird packets.

## NSE scripts

```bash
nmap -sC <ip>                 # default scripts (same as --script=default)
nmap --script vuln <ip>       # hunt for known vulns
nmap --script=banner <ip>     # grab service banners
```

`-sC` is the one that told me FTP allowed anonymous login and SMB signing was off.

## Timing (-T)

Goes 0 to 5, higher = faster AND louder. I kept mixing this up at first.

```
-T0 / -T1   slow and quiet (evade detection)
-T2         polite / slow
-T3         default
-T4         fast, what I use in the lab
-T5         insane, can miss ports if the network lags
```

`--min-rate 1000` forces a packet rate, separate from -T. Fast but noisy.

## Evasion (mostly beaten by modern firewalls, but good to know)

```bash
sudo nmap -f <ip>                     # fragment packets
sudo nmap --data-length 5 <ip>        # pad packets to break the Nmap signature
sudo nmap -D RND:5 <ip>               # decoys, hide your real IP in fake ones
```

## Saving output

```bash
nmap <ip> -oN scan.txt        # normal
nmap <ip> -oX scan.xml        # xml (for other tools)
nmap <ip> -oG scan.gnmap      # grepable
nmap <ip> -oA scan            # all three at once (what I use)
```

Add `-v` for verbose so you see stuff as it's found.

## The ones I reach for most

```bash
# full recon of one box
sudo nmap -A -T4 <ip> -oA fullscan

# what's alive + open across a subnet, fast
sudo nmap -sS -F 192.168.64.0/24

# find open ports first, then version-scan only those (way faster than -p- -sV)
sudo nmap -sS -p- <ip>
nmap -sV -p 21,22,25,139,445 <ip>
```

Only scan stuff you own or have permission to. For me that's my own VMs and TryHackMe.
