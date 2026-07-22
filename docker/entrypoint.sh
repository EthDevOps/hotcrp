#!/bin/sh
# hotcrp-entrypoint -- container startup for HotCRP.
#
# Waits for the database to accept connections, loads src/schema.sql the first
# time the database is empty, then hands off to the container command (Apache).
set -eu

# Only perform database setup when starting the web server. This keeps one-off
# invocations (batch scripts, `php -l`, a shell) from blocking on the database.
case "${1:-}" in
    apache2-foreground|apache2|httpd) ;;
    *) exec "$@" ;;
esac

DB_HOST="${HOTCRP_DB_HOST:-db}"
DB_PORT="${HOTCRP_DB_PORT:-3306}"
DB_NAME="${HOTCRP_DB_NAME:-hotcrp}"
DB_USER="${HOTCRP_DB_USER:-$DB_NAME}"
DB_PASSWORD="${HOTCRP_DB_PASSWORD:-}"

mysql_cmd() {
    # --skip-ssl: the MariaDB client defaults to requiring TLS, but HotCRP's
    # default (dbSsl off) talks plaintext to the DB, so match that here.
    mysql --skip-ssl --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
        ${DB_PASSWORD:+--password="$DB_PASSWORD"} "$@"
}

# Configure outgoing mail. HotCRP pipes messages to /usr/sbin/sendmail (msmtp);
# when HOTCRP_SMTP_HOST is set we generate an msmtp config that relays to that
# SMTP server. Without it, mail delivery is not configured.
if [ -n "${HOTCRP_SMTP_HOST:-}" ]; then
    echo "hotcrp: configuring SMTP relay via ${HOTCRP_SMTP_HOST}:${HOTCRP_SMTP_PORT:-587}"
    {
        echo "defaults"
        echo "logfile -"
        case "${HOTCRP_SMTP_TLS:-starttls}" in
            off|none) echo "tls off" ;;
            on|smtps) echo "tls on"; echo "tls_starttls off" ;;
            *)        echo "tls on"; echo "tls_starttls on" ;;
        esac
        echo "account default"
        echo "host ${HOTCRP_SMTP_HOST}"
        echo "port ${HOTCRP_SMTP_PORT:-587}"
        echo "from ${HOTCRP_EMAIL_FROM:-${HOTCRP_CONTACT_EMAIL:-hotcrp@localhost}}"
        if [ -n "${HOTCRP_SMTP_USER:-}" ]; then
            echo "auth on"
            echo "user ${HOTCRP_SMTP_USER}"
            echo "password ${HOTCRP_SMTP_PASSWORD:-}"
        else
            echo "auth off"
        fi
    } > /etc/msmtprc
    # msmtp refuses configs that are group/world readable.
    chmod 600 /etc/msmtprc
    chown www-data:www-data /etc/msmtprc
fi

echo "hotcrp: waiting for database ${DB_HOST}:${DB_PORT}..."
tries=0
until mysql_cmd --execute="SELECT 1" "$DB_NAME" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
        echo "hotcrp: database not reachable after 60 attempts; giving up." >&2
        exit 1
    fi
    sleep 2
done
echo "hotcrp: database is up."

# Load the schema once, detected by the absence of the Settings table.
if ! mysql_cmd --execute="SELECT 1 FROM Settings LIMIT 1" "$DB_NAME" >/dev/null 2>&1; then
    echo "hotcrp: empty database detected, loading src/schema.sql..."
    mysql_cmd "$DB_NAME" < /var/www/html/src/schema.sql
    echo "hotcrp: schema loaded."
else
    echo "hotcrp: existing schema found, skipping load."
fi

# Make sure runtime-writable directories are owned by the web server user.
# (Volumes mounted at runtime may come up root-owned.)
for d in conf docs logs; do
    if [ -d "/var/www/html/$d" ]; then
        chown www-data:www-data "/var/www/html/$d" 2>/dev/null || true
    fi
done

exec "$@"
