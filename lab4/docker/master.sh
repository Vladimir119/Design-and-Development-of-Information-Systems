#!/bin/sh
set -eu
mkdir -p /keys /public
chmod 700 /keys
if [ ! -f /keys/id_ed25519 ]; then
    ssh-keygen -q -t ed25519 -N '' -f /keys/id_ed25519
fi
cp /keys/id_ed25519.pub /public/id_ed25519.pub
exec sleep infinity
