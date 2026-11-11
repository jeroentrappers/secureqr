#!/usr/bin/env bash
# secureqr-firewall.sh — the preview container may reach the public internet and nothing else.
#
# The server's own proxy already refuses private addresses, but that check
# lives inside the container. If a hostile page ever broke out of the browser,
# the process could skip the proxy. These rules are the outer wall: traffic
# from the container's bridge to the host itself, to other containers, to the
# VPN or to any private range is rejected by the kernel.
#
# Safe to run again at any time (it replaces its own two chains in one step).
set -euo pipefail
. /etc/secureqr.env
BR="${SECUREQR_BRIDGE:?}"

# Not-public IPv4 space: private, carrier-grade NAT (Tailscale), link-local
# (cloud metadata), loopback, benchmarking, multicast and reserved.
NOT_PUBLIC="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/3"

{
  echo '*filter'
  # Declaring a chain here empties it as part of the same atomic load.
  echo ':SECUREQR-FWD - [0:0]'
  echo ':SECUREQR-IN - [0:0]'
  # Forwarded traffic (container -> elsewhere): replies are fine, private space is not.
  echo '-A SECUREQR-FWD -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN'
  for net in $NOT_PUBLIC; do echo "-A SECUREQR-FWD -d $net -j REJECT --reject-with icmp-port-unreachable"; done
  echo '-A SECUREQR-FWD -j RETURN'
  # Traffic to the host itself (any of its addresses): only replies to connections the host opened (nginx -> container).
  echo '-A SECUREQR-IN -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN'
  echo '-A SECUREQR-IN -j REJECT --reject-with icmp-port-unreachable'
  echo 'COMMIT'
} | iptables-restore -w --noflush

iptables -w -C DOCKER-USER -i "$BR" -j SECUREQR-FWD 2>/dev/null || iptables -w -I DOCKER-USER 1 -i "$BR" -j SECUREQR-FWD
iptables -w -C INPUT -i "$BR" -j SECUREQR-IN 2>/dev/null || iptables -w -I INPUT 1 -i "$BR" -j SECUREQR-IN
