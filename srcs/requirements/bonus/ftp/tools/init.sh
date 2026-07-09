#!/bin/bash
set -e

FTP_PASSWORD=$(cat /run/secrets/ftp_password)

if ! id "${FTP_USER}" >/dev/null 2>&1; then
    useradd -M -d /var/www/html -s /usr/sbin/nologin "${FTP_USER}"
fi

echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

grep -qx /usr/sbin/nologin /etc/shells || echo /usr/sbin/nologin >> /etc/shells

usermod -aG www-data "${FTP_USER}"
chmod -R g+w /var/www/html

mkdir -p /var/run/vsftpd/empty

echo "[ftp] starting vsftpd in the foreground..."
exec /usr/sbin/vsftpd /etc/vsftpd.conf
