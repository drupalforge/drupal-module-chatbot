#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Copyright (C) 2026 DevPanel
# You can install any service here to support your project
# Please make sure you run apt update before install any packages
# Example:
# - apt-get update
# - apt-get install nano
#
# ----------------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "custom_package_installer.sh must be run as root." >&2
  exit 1
fi

# Check if $PG_HOST is set, if not, set it to 'pgvector'.
if [ -z "${PG_HOST:-}" ]; then
  export PG_HOST="localhost"
fi

# Install APT packages.
if ! command -v npm >/dev/null 2>&1; then
  apt-get update
  apt-get install -y jq nano npm
fi

PECL_UPDATED=false
# Install APCU extension. Bypass question about enabling internal debugging.
if ! php --re apcu > /dev/null 2>&1; then
  $PECL_UPDATED || pecl update-channels && PECL_UPDATED=true
  pecl install apcu <<< ''
  echo 'extension=apcu.so' > /usr/local/etc/php/conf.d/apcu.ini
fi
# Install uploadprogress extension.
if ! php --re uploadprogress > /dev/null 2>&1; then
  $PECL_UPDATED || pecl update-channels && PECL_UPDATED=true
  pecl install uploadprogress
  echo 'extension=uploadprogress.so' > /usr/local/etc/php/conf.d/uploadprogress.ini
fi

#== Match the server to the client version shipped with the base image.
if [ -z "${PG_MAJOR:-}" ]; then
  if command -v psql >/dev/null 2>&1; then
    PG_MAJOR=$(psql --version | grep -oE '[0-9]+' | head -n1)
  else
    PG_MAJOR=18
  fi
fi

if [ ! -x "/usr/lib/postgresql/$PG_MAJOR/bin/postgres" ] || ! dpkg -s "postgresql-$PG_MAJOR-pgvector" >/dev/null 2>&1; then
  # Newer base images already configure the PostgreSQL apt repository in
  # pgdg.sources. A second entry with a different key makes apt unusable.
  if [ -f /etc/apt/sources.list.d/pgdg.sources ]; then
    rm -f /etc/apt/sources.list.d/pgdg.list
  elif [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    apt-get update
    apt-get install -y curl ca-certificates
    install -d /usr/share/postgresql-common/pgdg
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
    . /etc/os-release
    sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  fi
  apt-get update

  #== Install postgresql on the host.
  echo "PostgreSQL $PG_MAJOR is not installed. Installing it now."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "postgresql-$PG_MAJOR" "postgresql-$PG_MAJOR-pgvector" "postgresql-client-$PG_MAJOR"
fi
#== Make it less promiscuous in DDEV only.
if env | grep -q DDEV_PROJECT; then
  chmod 0755 /usr/bin
  chmod 0755 /usr/sbin
  #== Start the PostgreSQL service.
  env PATH="/usr/sbin:/usr/bin:/sbin:/bin" service postgresql start
else
  #== Start the postgresql service.
  service postgresql start
  #== Create the user and database if the image did not already provide them.
  if [ "$(su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname = 'db'\"")" != 1 ]; then
    su postgres -c "psql -c \"CREATE ROLE db WITH LOGIN PASSWORD 'db';\""
  fi
  if [ "$(su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname = 'db'\"")" != 1 ]; then
    su postgres -c "psql -c \"CREATE DATABASE db WITH OWNER db ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;\""
  fi
  #== Enable pgvector extension.
  su postgres -c "psql -d db -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
fi

# Make sure that php has pgsql installed.
if ! php --re pgsql > /dev/null 2>&1; then
  apt-get install -y libpq-dev
  docker-php-ext-install pgsql
fi

# Reload Apache if it's running.
if $PECL_UPDATED && /etc/init.d/apache2 status > /dev/null; then
  /etc/init.d/apache2 reload
fi
