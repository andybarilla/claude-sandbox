#!/bin/bash

# Hosts to whitelist with their allowed ports
# Format: "hostname ports..."
WHITELIST=(
  "api.anthropic.com 443"
  "claude.ai 443"
  "statsig.anthropic.com 443"
  "sentry.io 443"
  "github.com 443 22"
  "registry.npmjs.org 443"
)

# Resolve all hostnames to IPv4 while DNS is still open
declare -A RESOLVED
for entry in "${WHITELIST[@]}"; do
  host="${entry%% *}"
  ips=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u)
  if [ -z "$ips" ]; then
    echo "WARNING: could not resolve $host" >&2
  fi
  RESOLVED["$host"]="$ips"
done

# Now apply firewall rules
iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Whitelist resolved IPs
for entry in "${WHITELIST[@]}"; do
  read -r host ports <<< "$entry"
  for ip in ${RESOLVED["$host"]}; do
    for port in $ports; do
      iptables -A OUTPUT -d "$ip" -p tcp --dport "$port" -j ACCEPT
    done
  done
done

echo "Firewall rules applied."
