#!/bin/bash
set -e

if [ ! -z "${WAIT_INT}" ]; then
  /usr/bin/pipework --wait -i ${WAIT_INT}
fi

USERNAME=${USERNAME:-rsync}
PASSWORD=${PASSWORD:-rsync}
SSHPORT=${SSHPORT:-22}
ALLOW=${ALLOW:-192.168.0.0/16 172.16.0.0/12 10.0.0.0/24 127.0.0.1/32}
VOLUME=${VOLUME:-/data}

# Delete old PID file on reboot
rm -f /var/run/rsyncd.pid

# Set Allowed hosts and ports for SSH as well
ALLOWEDHOSTS=( $ALLOW ) 
for h in "${ALLOWEDHOSTS[@]}"
do
    echo "sshd : $h : allow" >> /etc/hosts.allow
done
echo "sshd : ALL : deny" >> /etc/hosts.allow

# Restarts not needed. Started later on this script anyway
sed -i "s/.*Port 22/Port $SSHPORT/g" /etc/ssh/sshd_config


if [ "$1" = 'rsync_server' ]; then

    if [ -e "/root/.ssh/authorized_keys" ]; then
        chmod 400 /root/.ssh/authorized_keys
        chown root:root /root/.ssh/authorized_keys
    fi
    exec /usr/sbin/sshd &

    echo "root:$PASSWORD" | chpasswd

    echo "$USERNAME:$PASSWORD" > /etc/rsyncd.secrets
    chmod 0400 /etc/rsyncd.secrets

    mkdir -p $VOLUME

    [ -f /etc/rsyncd.conf ] || cat <<EOF > /etc/rsyncd.conf
    pid file = /var/run/rsyncd.pid
    log file = /var/log/rsync.log
    timeout = 300
    max connections = 10
    port = 873

    [data]
        uid = root
        gid = root
        hosts deny = *
        hosts allow = ${ALLOW}
        read only = false
        path = ${VOLUME}
        comment = ${VOLUME} directory
        auth users = ${USERNAME}
        secrets file = /etc/rsyncd.secrets
EOF

    exec /usr/bin/rsync --no-detach --daemon --config /etc/rsyncd.conf "$@"
fi

exec "$@"
