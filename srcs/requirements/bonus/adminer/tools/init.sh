#!/bin/bash
set -e

mkdir -p /run/php

/usr/sbin/php-fpm8.2

echo "[adminer] starting nginx in the foreground..."
exec nginx -g "daemon off;"