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
