#!/bin/sh
set -eu
mkdir -p /run/sshd /root/.ssh
chmod 700 /root/.ssh
cp /public/id_ed25519.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -A
if [ -x /etc/init.d/supervisor ]; then
    /etc/init.d/supervisor start
fi
exec /usr/sbin/sshd -D -e
