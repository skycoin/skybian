#!/usr/bin/env bash

ARCHIVE_NAME="skywire-v0.4.1-linux-arm64.tar.gz"
RELEASE_URL="https://github.com/skycoin/skywire/releases/download/v0.4.1/$ARCHIVE_NAME"

MIGRATION_DIR="/var/skywire/migration"
MIGRATION_BIN="${MIGRATION_DIR}/bin"
MIGRATION_BACKUP="/var/skywire/backup/migration"
BACKUP_BIN=$MIGRATION_BACKUP/bin
BACKUP_CONF=$MIGRATION_BACKUP/conf
SYSTEMD_DIR="/etc/systemd/system"

SYSTEMD_FILE_OLD="/etc/systemd/system/skywire-startup.service"

main() {
	prepare_old
	prepare
	update_binaries
	update_configs
	finalize
}

prepare_old() {
	echo "Checking for old systemd service..."

	if [ -f "$SYSTEMD_FILE_OLD" ]; then
	curl -o /etc/systemd/system/skywire-visor.service https://raw.githubusercontent.com/skycoin/skybian/master/static/skywire-visor.service
	systemctl daemon-reload
	systemctl disable skywire-startup.service
	fi
}

prepare() {
	echo "Preparing..."
	# install jq to merge json configurations

	# update doesn't seem to work for now
	#apt update
	apt install -y jq

	mkdir -p $BACKUP_CONF $BACKUP_BIN $MIGRATION_DIR $MIGRATION_BIN

	echo "Downloading release..."
	
	wget -c $RELEASE_URL -O "${MIGRATION_BIN}/${ARCHIVE_NAME}"
	tar xfzv "${MIGRATION_BIN}/${ARCHIVE_NAME}" -C $MIGRATION_BIN

	# stop service
	echo "stopping and disabling services..."
	systemctl stop skywire-visor.service
	sleep 2
	systemctl disable skywire-visor.service
	systemctl stop skywire-hypervisor.service
	sleep 2
	systemctl disable skywire-hypervisor.service
}

update_binaries() {
	echo "Removing old binaries..."
	mv $SYSTEMD_DIR/skybian-firstrun.service $MIGRATION_BACKUP
	cp $SYSTEMD_DIR/skywire-visor.service $MIGRATION_BACKUP 2> /dev/null
	mv $SYSTEMD_DIR/skywire-hypervisor.service $MIGRATION_BACKUP 2> /dev/null
	mv /usr/bin/skybian-firstrun $MIGRATION_BACKUP
	mv /usr/bin/skywire-hypervisor $MIGRATION_BACKUP 2> /dev/null
	mv /usr/bin/skywire-visor $MIGRATION_BACKUP 2> /dev/null
	mv /usr/bin/apps/skychat $BACKUP_BIN
	mv /usr/bin/apps/skysocks $BACKUP_BIN
	mv /usr/bin/apps/skysocks-client $BACKUP_BIN
	mv /usr/bin/apps/vpn-client $BACKUP_BIN
	mv /usr/bin/apps/vpn-server $BACKUP_BIN

	echo "Setting up new binaries..."
	mv "${MIGRATION_BIN}/skywire-visor" /usr/bin/
	mv "${MIGRATION_BIN}/apps/skychat" /usr/bin/apps/
	mv "${MIGRATION_BIN}/apps/skysocks" /usr/bin/apps/
	mv "${MIGRATION_BIN}/apps/skysocks-client" /usr/bin/apps/
	mv "${MIGRATION_BIN}/apps/vpn-client" /usr/bin/apps/
	mv "${MIGRATION_BIN}/apps/vpn-server" /usr/bin/apps/
}

update_configs() {
	echo "Removing old configs..."
	# move existing configs
	mv /etc/skywire-visor.json $BACKUP_CONF 2> /dev/null
	mv /etc/skywire-hypervisor.json $BACKUP_CONF 2> /dev/null

	# change skywire-visor service to support new binary
	sed -i 's#ExecStart.*#ExecStart=/usr/bin/skywire-visor -c /etc/skywire-config.json#' $SYSTEMD_DIR/skywire-visor.service
	if [ -f "${BACKUP_CONF}/skywire-visor.json" ] ; then
		gen_visor_config
	fi

	if [ -f "${BACKUP_CONF}/skywire-hypervisor.json" ] ; then
		gen_hypervisor_config
	fi
}

finalize() {
	# reload systemd service definitions
	systemctl daemon-reload
	systemctl enable skywire-visor.service
	rm -rf $MIGRATION_BIN/*
	reboot
}

# looks like merged visor/hypervisor config format is compatible
# with old visor, so no chages required
gen_visor_config() {
	echo "Generating visor config..."
	# todo: update transport log location?
	cp "${BACKUP_CONF}/skywire-visor.json" /etc/skywire-config.json
}

gen_hypervisor_config() {
	echo "Generating hypervisor config..."

	local SRC="${BACKUP_CONF}/skywire-hypervisor.json"
	local RESULT="${BACKUP_CONF}/skywire-config.json"
	local PK=$(jq '.public_key' $SRC)
	local SK=$(jq '.secret_key' $SRC)

	# if someone is running both visor and hypervisor, use existing visor config
	# as a template
	if [ -f "${BACKUP_CONF}/skywire-visor.json" ] ; then
		HV_CONF_TPL=$(cat "${BACKUP_CONF}/skywire-visor.json")
	fi

    # add hypervisor key
	echo "$HV_CONF_TPL" | jq '.hypervisor={}' > $RESULT

    update_key $SRC ".public_key" ".pk" $RESULT
    update_key $SRC ".secret_key" ".sk" $RESULT
    update_key $SRC ".db_path" ".hypervisor.db_path" $RESULT
    update_key $SRC ".enable_auth" ".hypervisor.enable_auth" $RESULT
    update_key $SRC ".cookies" ".hypervisor.cookies" $RESULT
    update_key $SRC ".dmsg_port" ".hypervisor.dmsg_port" $RESULT
    update_key $SRC ".http_addr" ".hypervisor.http_addr" $RESULT
    update_key $SRC ".enable_tls" ".hypervisor.enable_tls" $RESULT
    update_key $SRC ".tls_cert_file" ".hypervisor.tls_cert_file" $RESULT
    update_key $SRC ".tls_key_file" ".hypervisor.tls_key_file" $RESULT
	mv $RESULT /etc/skywire-config.json
}

# accept 4 arguments: source, key, target key and target
# look for the key under source, and put it into the target
# under target key
update_key() {
	local SRC=${1:?Need source from which to update}
	local KEY=${2:?Need key to update}
	local TARGET_KEY=${3:?Need target key}
	local TARGET=${4:?Need json file as a target}
	local VAL=$(cat $SRC | jq "$KEY")    
    local RES=$(jq "$TARGET_KEY=$VAL" "$TARGET")
    echo "$RES" > $TARGET
}

HV_CONF_TPL='
{
	"version": "v1.0.0",
	"sk": "3291b0af73b2ac7287188ddb5e03fb49c8ac445e2efa2d4aa4dbb0e5162ab9e2",
	"pk": "034904885ee8905abcc3fd005dd15c5dab656afa400521725e7627a059dd994a31",
	"dmsg": {
		"discovery": "http://dmsg.discovery.skywire.skycoin.com",
		"sessions_count": 1
	},
	"dmsgpty": {
		"port": 22,
		"authorization_file": "./dmsgpty/whitelist.json",
		"cli_network": "unix",
		"cli_address": "/tmp/dmsgpty.sock"
	},
	"stcp": {
		"pk_table": null,
		"local_address": ":7777"
	},
	"transport": {
		"discovery": "http://transport.discovery.skywire.skycoin.com",
		"address_resolver": "http://address.resolver.skywire.skycoin.com",
		"log_store": {
			"type": "file",
			"location": "./transport_logs"
		},
		"trusted_visors": null
	},
	"routing": {
		"setup_nodes": [
			"0324579f003e6b4048bae2def4365e634d8e0e3054a20fc7af49daf2a179658557"
		],
		"route_finder": "http://routefinder.skywire.skycoin.com",
		"route_finder_timeout": "10s"
	},
	"uptime_tracker": {
		"addr": "http://uptime-tracker.skywire.skycoin.com"
	},
	"launcher": {
		"discovery": {
			"update_interval": "30s",
			"proxy_discovery_addr": "http://service.discovery.skycoin.com"
		},
		"apps": [
			{
				"name": "skychat",
				"args": [
					"-addr",
					":8001"
				],
				"auto_start": true,
				"port": 1
			},
			{
				"name": "skysocks",
				"auto_start": true,
				"port": 3
			},
			{
				"name": "skysocks-client",
				"auto_start": false,
				"port": 13
			},
			{
				"name": "vpn-server",
				"auto_start": false,
				"port": 44
			},
			{
				"name": "vpn-client",
				"auto_start": false,
				"port": 43
			}
		],
		"server_addr": "localhost:5505",
		"bin_path": "/usr/bin/apps",
		"local_path": "/var/skywire-visor/apps"
	},
	"hypervisors": [],
	"cli_addr": "localhost:3435",
	"log_level": "info",
	"shutdown_timeout": "10s",
	"restart_check_delay": "1s"
}
'

main "$@"
