#!/bin/bash
#/usr/bin/skymanager
# Runs once on first boot (via skymanager.service).
#
# Flow:
#  1. Ensure a visor config exists at /opt/skywire/skywire.json so we have a
#     real pubkey to identify ourselves to a peer hypervisor (the hypervisor's
#     /api/pk route enforces a soft SW-Public header check; the header must
#     be a curve-valid cipher.PubKey, so we can't fake one).
#  2. Probe ${gateway%.*}.2:8000/api/ping. If something answers, fetch the
#     hypervisor's pubkey from :8000/api/pk (carrying our own PK in SW-Public)
#     and configure as a visor of that hypervisor.
#  3. If nothing answers on .2, claim it as a static address and become the
#     hypervisor (the /api/pk route is registered because
#     ENABLEPKENDPOINT=true is in /etc/profile.d/skyenv.sh, set by
#     skybian-chrootconfig / skyalarm-firstboot).
#  4. Hand off to skywire-autoconfig, then self-disable.
#
# Discovery used to use a separate `srvpk` http endpoint on :7998. That was
# retired in favor of the hypervisor's UI port (:8000). `skywire-cli`'s
# local RPC (:3435) is localhost-only and must stay that way.

if [[ $EUID -ne 0 ]]; then
	echo "root permissions required"
	exit 1
fi

# Reset path: if a previous skymanager run wrote network config, remove it
# and exit (used by skybian-reset).
if [[ -f /etc/systemd/network/10-eth.network ]] ; then
	echo "removing static ip configuration"
	rm /etc/systemd/network/10-eth.network
	systemctl restart systemd-networkd networking NetworkManager 2>/dev/null || true
	[[ -f /etc/systemd/system/skywire.service.d/10-skywire_10.conf ]] && \
		rm /etc/systemd/system/skywire.service.d/10-skywire_10.conf
	exit 0
fi

# Belt-and-braces — chrootconfig writes this to skyenv.sh at image-build
# time, but on ALARM images skyenv.sh may not yet exist when skymanager
# first runs. Export it here so the config gen below picks up the
# --pk-endpoint default.
export ENABLEPKENDPOINT=true

# --- Step 1: materialize visor config to get our own PK ---
_skyconf=/opt/skywire/skywire.json
mkdir -p "$(dirname "${_skyconf}")"
if [[ ! -f "${_skyconf}" ]]; then
	# Plain visor config — skywire-autoconfig will re-gen with -r later to
	# add -i (hypervisor) or -j PK (remote hypervisor) as appropriate.
	# -r retains the keypair, so our PK below stays stable.
	skywire-cli config gen -o "${_skyconf}" >/dev/null
fi

# Extract our own pubkey from the generated config.
_my_pk="$(grep -oE '"pk":[[:space:]]*"[0-9a-fA-F]{66}"' "${_skyconf}" \
	| head -n1 | grep -oE '[0-9a-fA-F]{66}')"
if [[ -z "${_my_pk}" ]]; then
	echo "skymanager: could not extract own pubkey from ${_skyconf}"
	exit 1
fi

# --- Step 2: probe .2 on the current subnet ---
_gateway="$(ip route show | awk '/^default via/{print $3; exit}')"
[[ -z "${_gateway}" ]] && echo "gateway ip unknown" && exit 1
_ip="${_gateway%.*}.2"

_pubkey=""
_nohv=""
if curl -fsS --max-time 3 "http://${_ip}:8000/api/ping" >/dev/null 2>&1 ; then
	# Hypervisor is up. Ask for its pubkey, identifying ourselves via the
	# SW-Public header (66-hex; must pass cipher.PubKey curve verification).
	_pubkey="$(curl -fsS --max-time 5 \
		-H "SW-Public: ${_my_pk}" \
		"http://${_ip}:8000/api/pk" 2>/dev/null \
		| grep -oE '[0-9a-fA-F]{66}' | head -n1)"
	if [[ -z "${_pubkey}" ]]; then
		# Possible causes: the peer doesn't have EnablePKEndpoint set,
		# our SW-Public was rejected, or it's not actually a hypervisor.
		# Come up standalone; operator can re-run skywire-autoconfig.
		echo "warning: peer at ${_ip}:8000 didn't return a usable pubkey; coming up standalone"
		_nohv=1
	else
		echo "hypervisor detected at ${_ip}, pk=${_pubkey}"
	fi
else
	# --- Step 3: nobody on .2 — claim it ---
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

# --- Step 4: skywire-autoconfig + finalize ---
if [[ -n "${_pubkey}" ]]; then
	# Visor of discovered hypervisor.
	skywire-autoconfig "${_pubkey}"
elif [[ -n "${_nohv}" ]]; then
	# Standalone visor (no hypervisor wired).
	skywire-autoconfig 1
else
	# Local hypervisor.
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
