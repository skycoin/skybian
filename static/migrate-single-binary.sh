#!/usr/bin/env bash

MIGRATION_DIR="/var/skywire/migration"
MIGRATION_BIN="${MIGRATION_DIR}/bin/"
RELEASE_ARCHIVE="https://github.com/i-hate-nicknames/skywire/releases/download/v0.3.1-experimental/skywire-v0.3.1-experimental-linux-arm64.tar.gz"

MIGRATION_BACKUP="/var/skywire/backup/migration/"
BACKUP_SERVICE=$MIGRATION_BACKUP/service
BACKUP_BIN=$MIGRATION_BACKUP/bin
BACKUP_CONF=$MIGRATION_BACKUP/conf
SYSTEMD_DIR="/etc/systemd/system/"

echo "Preparing..."
apt update && apt install -y jq

mkdir -p $BACKUP_SERVICE $BACKUP_CONF $BACKUP_BIN $MIGRATION_DIR $MIGRATION_BIN

echo "Downloading release..."
cd $MIGRATION_BIN
rm -rf *
wget $RELEASE_ARCHIVE
tar xf $RELEASE_ARCHIVE

# stop service
echo "stopping and disabling services..."
systemctl stop skywire-visor.service
sleep 2
systemctl disable skywire-visor.service
systemctl stop skywire-hypervisor.service
sleep 2
systemctl disable skywire-hypervisor.service

echo "removing old binaries and service definitions..."
mv $SYSTEM_DIR/skybian-firstrun.service $MIGRATION_BACKUP
cp $SYSTEM_DIR/skywire-visor.service $MIGRATION_BACKUP
mv $SYSTEM_DIR/skywire-hypervisor.service $MIGRATION_BACKUP
mv /usr/bin/skybian-firstrun $MIGRATION_BACKUP
mv /usr/bin/skywire-hypervisor $MIGRATION_BACKUP
mv /usr/bin/skywire-visor $MIGRATION_BACKUP
mv /usr/bin/apps/ $MIGRATION_BACKUP

echo "removing old configs..."

mv /etc/skywire-visor.json $MIGRATION_BACKUP 2> /dev/null
mv /etc/skywire-hypervisor.json $MIGRATION_BACKUP 2> /dev/null

echo "setting up new binaries and services"
# todo: download and extract
mv "${MIGRATION_BIN}/skywire-visor" /usr/bin/
mv "${MIGRATION_BIN}/apps/" /usr/bin/

# change skywire-visor service to support new binary
sed -i 's#ExecStart.*#ExecStart=/usr/bin/skywire-visor -c /etc/skywire-config.json#' $SYSTEM_DIR/skywire-visor.service

# todo: generate config file

# endconf


# reload systemd service definitions
systemctl daemon-reload

systemctl start skywire-visor.service


HV_CONF_OLD='
{
	"public_key": "03510100850eaa87370fb91071a5c5e27e5fb632dd7546aab4ce45e2ff04aa637e",
	"secret_key": "1b74960570450a991728cbe1d71f34b1cae041ce08bbad8acc10a50e7e9dbf06",
	"db_path": "/var/skywire-hypervisor/users.db",
	"enable_auth": true,
	"cookies": {
		"hash_key": "6ecbe9acc0d6bdb13a86c0cfdba626992edba6b3c750eef96fee76f856d276085a4502e7ac0ea972517dd34efc4c3ae9d65cc323abf8e4d650f4afd1e629cbaa",
		"block_key": "05fa5c049a19cbfb87f99786df2259752bd096de642f9cb7d54b0350fb6970a4",
		"expires_duration": 43200000000000,
		"path": "/",
		"domain": ""
	},
	"dmsg_discovery": "http://dmsg.discovery.skywire.skycoin.com",
	"dmsg_port": 46,
	"http_addr": ":8000",
	"enable_tls": false,
	"tls_cert_file": "/etc/skywire-hypervisor/cert.pem",
	"tls_key_file": "/etc/skywire-hypervisor/key.pem"
}
'

HV_CONF_NEW='
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
		"bin_path": "./apps",
		"local_path": "./local"
	},
	"hypervisors": [],
	"cli_addr": "localhost:3435",
	"log_level": "info",
	"shutdown_timeout": "10s",
	"restart_check_delay": "1s",
	"hypervisor": {
		"db_path": "/home/nvm/work/sky/skywire/users.db",
		"enable_auth": false,
		"cookies": {
			"hash_key": "ddbfd2c875b159294fb8c0be7ea37db85d16e258befec2894f5991afd787a07e4854bbb79c7597364f3f1a955af6365b51ece6cafb0f781d8b19d17079fb21ab",
			"block_key": "b1881cd1b4cb0a732bc4ad8d0c1d56f3fe8d54e4aea55dd4f19e52a55ccaa8ba",
			"expires_duration": 43200000000000,
			"path": "/",
			"domain": ""
		},
		"dmsg_port": 46,
		"http_addr": ":8000",
		"enable_tls": false,
		"tls_cert_file": "./ssl/cert.pem",
		"tls_key_file": "./ssl/key.pem"
	}
}
'