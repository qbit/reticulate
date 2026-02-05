#!/bin/sh

set -e

echo "==> Installing dependencies"
opkg update
opkg install python3 python3-pip python3-cryptography python3-pyserial shadow-su shadow-useradd shadow-groupadd

echo "==> Installing Reticulum Network Stack"
pip install --upgrade rns lxmf rnsh

echo "==> Creating rns group and user"
grep -q rns /etc/group || groupadd -g 142 rns
grep -q rns /etc/passwd || useradd -r -m -d /var/rns -s /bin/false -g 142 -c 'Reticulum User' rns

echo "==> Configuring OpenWRT specific bits"
[ -d "/lib/upgrade/keep.d" ] || mkdir -p /lib/upgrade/keep.d/
echo "/etc/rns" > /lib/upgrade/keep.d/rns
echo "/etc/rns" >> /etc/sysupgrade.conf

# Preserve opkg lists
sed -i -e "/^lists_dir\s/s:/var/opkg-lists$:/usr/lib/opkg/lists:" /etc/opkg.conf

echo "==> Creating rns specific configurations"
mkdir -p /etc/rns
chown rns: /etc/rns

RNS_RULES=$(cat <<EOF
config rule
        option name 'RNS 42671 lan'
        option src 'lan'
        option target 'ACCEPT'
        list proto 'udp'
        option dest_port '42671'

config rule
        option name 'RNS 42671 wan'
        option src 'wan'
        option target 'ACCEPT'
        list proto 'udp'
        option dest_port '42671'

config rule
        option name 'RNS 29716 wan'
        option src 'wan'
        option target 'ACCEPT'
        list proto 'udp'
        option dest_port '29716'

config rule
        option name 'RNS 29716 lan'
        option src 'lan'
        option target 'ACCEPT'
        list proto 'udp'
        option dest_port '29716'

EOF
)

RNS_INIT=$(cat <<EOF
#!/bin/sh /etc/rc.common

START=27
USE_PROCD=1

PROG="/usr/bin/rnsd"
RUN_DIR="/etc/rns"
USER="rns"

start_service() {
        mkdir -m 0755 -p \${RUN_DIR}
        chown -R \${USER}:\${USER} \${RUN_DIR}

        args="-s -vvv --config /etc/rns"

        logger -t rns "Running command: \${PROG} \${args}"

        procd_open_instance
        procd_set_param command \${PROG} \${args}
        procd_set_param env HOME=\${RUN_DIR}
        procd_set_param pidfile /var/run/rns.pid
        procd_set_param file /etc/config/rns
        procd_set_param stderr 1
        procd_set_param stdout 1
        procd_set_param term_timeout 15
        procd_set_param user \${USER}
        procd_set_param group \${USER}
        procd_set_param respawn \${respawn_threshold:-3600} \${respawn_timeout:-10} \${respawn_retry:-5}
        procd_close_instance
}

reload_service() {
        logger -t rns "Reloading service..."
        stop
        start
}

service_triggers() {
        procd_add_reload_trigger "rns"
}
EOF
)

RNS_CONFIG=$(cat <<EOF
config rns 'main' option enabled '1'
EOF
)

echo "${RNS_INIT}" > /etc/init.d/rns
chmod +x /etc/init.d/rns
echo "${RNS_CONFIG}" > /etc/config/rns

if ! grep -q 'RNS 29716' /etc/config/firewall; then
    echo "==> Installing RNS firewall rules"
    if grep -q '^# Allow IPv4 ping' /etc/config/firewall; then
	awk -v rules="$RNS_RULES" \
	    '$0 == "# Allow IPv4 ping" {print rules}1' /etc/config/firewall > /etc/config/firewall.rns
	mv /etc/config/firewall.rns /etc/config/firewall
	/etc/init.d/firewall reload
    else
	echo "==> Non-default firewall found, please add the following rules:"
	echo "$RNS_RULES"
    fi
fi

