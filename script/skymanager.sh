#!/bin/bash
#/usr/bin/skymanager
# Runs once on first boot (via skymanager.service, After=install-skywire.service).
#
# Flow:
#  1. Ensure /etc/skywire.conf has ENABLEPKENDPOINT=true so every subsequent
#     `skywire cli config gen` (called by `skywire autoconfig`) flips on the
#     unauthenticated GET /api/pk route in the generated visor config. The
#     flag is read from $SKYENV (=/etc/skywire.conf) by the cli's
#     scriptExecBool path — setting ENABLEPKENDPOINT in the shell env does
#     NOT propagate; it has to live in this file. cli config gen sets
#     EnablePKEndpoint unconditionally from the flag on every regen, so
#     this also can't be left to `-r` retention.
#  2. Probe ${gateway%.*}.2:8000/api/ping.
#       - No answer → claim .2 as static IP and `skywire autoconfig 0`
#         (local hypervisor).
#       - Answer → `skywire autoconfig 1` first (creates the visor config
#         and PK with no remote hv wired), then fetch the hypervisor's
#         pubkey from :8000/api/pk carrying our own PK in SW-Public, then
#         `skywire autoconfig <hv-pk>` to register the remote hypervisor.
#         `-r` retention on the second autoconfig keeps the keypair stable,
#         so the PK we put in SW-Public stays valid.
#  3. Self-disable so subsequent boots don't redo the dance.
#
# Discovery used to use srvpk.service on :7998. That was retired in favor
# of the hypervisor's UI port :8000. `skywire cli`'s local RPC (:3435) is
# localhost-only and must stay that way.

if [[ $EUID -ne 0 ]]; then
	echo "root permissions required"
	exit 1
fi

# Reset path: previous run wrote network config — undo and exit
# (used by skybian-reset).
if [[ -f /etc/systemd/network/10-eth.network ]] ; then
	echo "removing static ip configuration"
	rm /etc/systemd/network/10-eth.network
	systemctl restart systemd-networkd networking NetworkManager 2>/dev/null || true
	[[ -f /etc/systemd/system/skywire.service.d/10-skywire_10.conf ]] && \
		rm /etc/systemd/system/skywire.service.d/10-skywire_10.conf
	exit 0
fi

# --- Step 1: flip on EnablePKEndpoint in the skyenv file ---
# /etc/skywire.conf is the canonical SKYENV file. cli config gen evaluates
# `${ENABLEPKENDPOINT:-false}` against THIS file (not against the process
# env), so the line must be present here before autoconfig fires.
_skyenv=/etc/skywire.conf
mkdir -p "$(dirname "${_skyenv}")"
touch "${_skyenv}"
if grep -q '^ENABLEPKENDPOINT=' "${_skyenv}" ; then
	# Existing line — make sure it's true. Comments-out lines (#ENABLEPKENDPOINT=...)
	# are left alone since they wouldn't be picked up anyway.
	sed -i 's/^ENABLEPKENDPOINT=.*/ENABLEPKENDPOINT=true/' "${_skyenv}"
else
	echo 'ENABLEPKENDPOINT=true' >> "${_skyenv}"
fi
# TODO(release-pin): once skybian's _skywirever pins a release that includes
# https://github.com/skycoin/skywire/pull/2901 (--pk-endpoint flag on
# `skywire autoconfig`), drop the file poke above and pass --pk-endpoint
# on the autoconfig calls below instead.

# --- Step 2: probe .2 on the current subnet ---
# Retry-probe with a 2-minute window. The skyminer power bus has thin
# traces — when the main switch turns on all 8 boards at once, voltage
# dips can stall the hypervisor's boot for up to a minute or so. A
# single-shot probe would race ahead and have the visors try to claim
# .2 themselves. Polling lets the hypervisor stabilize and start
# answering /api/ping before we give up.
_gateway="$(ip route show | awk '/^default via/{print $3; exit}')"
[[ -z "${_gateway}" ]] && echo "gateway ip unknown" && exit 1
_ip="${_gateway%.*}.2"

_probe_timeout=120   # seconds
_probe_interval=5    # seconds
_hv_up=
_probe_elapsed=0
echo "probing ${_ip}:8000/api/ping (up to ${_probe_timeout}s, every ${_probe_interval}s)"
while (( _probe_elapsed < _probe_timeout )); do
	if curl -fsS --max-time 3 "http://${_ip}:8000/api/ping" >/dev/null 2>&1 ; then
		_hv_up=1
		break
	fi
	sleep "${_probe_interval}"
	_probe_elapsed=$((_probe_elapsed + _probe_interval))
done

if [[ -n "${_hv_up}" ]]; then
	# Hypervisor is up at .2. Materialize OUR visor config first so we
	# have a real PK to advertise in SW-Public — `cipher.PubKey.Set()`
	# does curve verification, fake hex doesn't pass.
	echo "hypervisor detected at ${_ip}:8000; bootstrapping visor config"
	skywire autoconfig 1

	# Extract our own pubkey from the freshly-generated config.
	_skyconf=/opt/skywire/skywire.json
	_my_pk="$(grep -oE '"pk":[[:space:]]*"[0-9a-fA-F]{66}"' "${_skyconf}" \
		| head -n1 | grep -oE '[0-9a-fA-F]{66}')"
	if [[ -z "${_my_pk}" ]]; then
		echo "skymanager: could not extract own pubkey from ${_skyconf} — coming up standalone"
	else
		# Ask the hypervisor for its pubkey. /api/pk requires a curve-valid
		# SW-Public header; the route also has to be enabled on the
		# hypervisor (EnablePKEndpoint=true in its skywire.conf).
		_hv_pk="$(curl -fsS --max-time 5 \
			-H "SW-Public: ${_my_pk}" \
			"http://${_ip}:8000/api/pk" 2>/dev/null \
			| grep -oE '[0-9a-fA-F]{66}' | head -n1)"
		if [[ -n "${_hv_pk}" ]]; then
			echo "registering remote hypervisor pk=${_hv_pk}"
			# `-r` retains our keypair so the PK we advertised stays stable.
			skywire autoconfig "${_hv_pk}"
		else
			echo "warning: peer at ${_ip}:8000 didn't return a usable pubkey; staying standalone"
		fi
	fi
else
	# --- Step 3: nobody on .2 — claim it and become hypervisor ---
	# Random jitter before claiming. Only matters in the degenerate
	# case where the operator skipped the hypervisor preboot and all 8
	# boards reach the timeout simultaneously: one wins the claim, the
	# rest re-probe within their own remaining time and discover the
	# winner. On the happy path (hypervisor was preboot'd, this board's
	# first boot is on its own) the jitter is wasted but harmless.
	_jitter=$((RANDOM % 30))
	echo "no hypervisor at ${_ip}:8000 after ${_probe_timeout}s; sleeping ${_jitter}s before claim (race-break)"
	sleep "${_jitter}"

	# Final re-probe right before claiming — someone else may have won
	# the race during our jitter sleep.
	if curl -fsS --max-time 3 "http://${_ip}:8000/api/ping" >/dev/null 2>&1 ; then
		echo "another board claimed ${_ip} during jitter window; joining as visor"
		skywire autoconfig 1
		_skyconf=/opt/skywire/skywire.json
		_my_pk="$(grep -oE '"pk":[[:space:]]*"[0-9a-fA-F]{66}"' "${_skyconf}" \
			| head -n1 | grep -oE '[0-9a-fA-F]{66}')"
		if [[ -n "${_my_pk}" ]]; then
			_hv_pk="$(curl -fsS --max-time 5 \
				-H "SW-Public: ${_my_pk}" \
				"http://${_ip}:8000/api/pk" 2>/dev/null \
				| grep -oE '[0-9a-fA-F]{66}' | head -n1)"
			[[ -n "${_hv_pk}" ]] && skywire autoconfig "${_hv_pk}"
		fi
	else
		echo "claiming ${_ip} as static IP and becoming hypervisor"
		cat > /etc/systemd/network/10-eth.network <<EOF
[Match]
Name=eth*

[Network]
Address=${_ip}/24
Gateway=${_gateway}
DNS=${_gateway}
EOF
		systemctl restart systemd-networkd
		skywire autoconfig 0
	fi
fi

# --- Step 4: finalize ---
if [[ -f /opt/skywire/skywire.json ]] ; then
	mkdir -p /etc/systemd/system/skywire.service.d
	{
		echo "[Service]"
		echo "Environment=SKYBIAN=true"
		[[ -n "${_hv_pk}" ]] && echo "Environment=AUTOPEERHV=${_hv_pk}"
	} > /etc/systemd/system/skywire.service.d/10-skywire_10.conf
	systemctl daemon-reload
	systemctl disable skymanager 2>/dev/null || true
	systemctl enable --now skywire 2>/dev/null || true
	systemctl restart skywire 2>/dev/null || true
fi
