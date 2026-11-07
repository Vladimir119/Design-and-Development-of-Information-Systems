#!/bin/sh
set -eu
cd /opt/labapp
exec /usr/bin/python3 -u app.py
