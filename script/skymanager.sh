#!/bin/bash
#/usr/bin/skymanager
# Runs once on first boot (via skymanager.service).
#
# Flow:
#  1. Look at ${gateway%.*}.2 (i.e. the .2 IP on the current subnet).
#  2. If nothing answers there: claim .2 as a static address via
#     /etc/systemd/network/10-eth.network, become hypervisor.
#  3. If something is there: stay on DHCP, fetch its pubkey from the
#     hypervisor UI's unauthenticated /api/pk endpoint on port 8000,
#     configure self as a visor pointed at that hypervisor pk.
#  4. In either case, run skywire-autoconfig and start skywire, then
#     self-disable so subsequent boots don't redo the dance.
#
# Discovery used to use a separate `srvpk` http endpoint on :7998. That's
# been retired in favor of the hypervisor's own UI port (:8000). The pubkey
# endpoint must be unauthenticated — see /api/pk in skywire's hypervisor.go.

if [[ $EUID -ne 0 ]]; then
	echo "root permissions required"
	exit 1
fi

# Reset path: if a previous skymanager run already wrote network config,
# remove it and exit (handy for skybian-reset).
if [[ -f /etc/systemd/network/10-eth.network ]] ; then
	echo "removing static ip configuration"
	rm /etc/systemd/network/10-eth.network
	systemctl restart systemd-networkd networking NetworkManager 2>/dev/null || true
	[[ -f /etc/systemd/system/skywire.service.d/10-skywire_10.conf ]] && \
		rm /etc/systemd/system/skywire.service.d/10-skywire_10.conf
	exit 0
fi

# Determine the gateway IP and the target hypervisor address (.2 on the
# current subnet).
_gateway="$(ip route show | awk '/^default via/{print $3; exit}')"
[[ -z "${_gateway}" ]] && echo "gateway ip unknown" && exit 1
_ip="${_gateway%.*}.2"

# Probe :8000 — the hypervisor UI port. /api/ping is unauthenticated and
# cheap. `curl -fsS --max-time 3` returns nonzero if nothing answers within
# 3 seconds, which is our trigger to claim .2.
_pubkey=""
_nohv=""
if curl -fsS --max-time 3 "http://${_ip}:8000/api/ping" >/dev/null 2>&1 ; then
	# Something answered — assume it's the hypervisor. Fetch its pubkey
	# from the (unauthenticated) /api/pk route. The route returns a JSON
	# envelope {"public_key":"<66-hex>"}; grep for the first 66-hex run
	# rather than pulling in jq.
	_pubkey="$(curl -fsS --max-time 5 "http://${_ip}:8000/api/pk" 2>/dev/null | grep -oE '[0-9a-fA-F]{66}' | head -n1)"
	if [[ -z "${_pubkey}" ]]; then
		echo "warning: hypervisor responded at ${_ip}:8000 but /api/pk returned no usable pubkey; coming up without remote hypervisor"
		_pubkey=""
		_nohv=1
	else
		echo "hypervisor detected at ${_ip}, pk=${_pubkey}"
	fi
else
	# Nothing on .2 — claim it.
	echo "no hypervisor at ${_ip}:8000; claiming static IP and becoming hypervisor"
	cat > /etc/systemd/network/10-eth.network <<EOF
[Match]
Name=eth*

[Network]
Address=${_ip}/24
Gateway=${_gateway}
DNS=${_gateway}
EOF
	systemctl restart systemd-networkd
fi

# Hand off to skywire-autoconfig. If we have a pubkey, pass it as the remote
# hypervisor pk; otherwise pass nothing (autoconfig defaults to making this
# node a hypervisor when no arg is given).
if [[ -n "${_pubkey}" ]]; then
	skywire-autoconfig "${_pubkey}"
elif [[ -n "${_nohv}" ]]; then
	# Detected a peer but couldn't get a pk: come up as a standalone visor
	# (no hypervisor wired). Operator can rerun skywire-autoconfig manually.
	skywire-autoconfig 1
else
	# .2 was free — we're the hypervisor.
	skywire-autoconfig 0
fi

if [[ -f /opt/skywire/skywire.json ]] ; then
	mkdir -p /etc/systemd/system/skywire.service.d
	{
		echo "[Service]"
		echo "Environment=SKYBIAN=true"
		[[ -n "${_pubkey}" ]] && echo "Environment=AUTOPEERHV=${_pubkey}"
	} > /etc/systemd/system/skywire.service.d/10-skywire_10.conf
	systemctl daemon-reload
	systemctl disable skymanager 2>/dev/null || true
	systemctl enable --now skywire 2>/dev/null || true
	systemctl restart skywire 2>/dev/null || true
fi
