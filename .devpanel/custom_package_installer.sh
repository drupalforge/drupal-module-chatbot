#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Copyright (C) 2024 DevPanel
# You can install any service here to support your project
# Please make sure you run apt update before install any packages
# Example:
# - sudo apt-get update
# - sudo apt-get install nano
#
# ----------------------------------------------------------------------

# Check if $PG_HOST is set, if not, set it to 'pgvector'.
if [ -z "${PG_HOST:-}" ]; then
  export PG_HOST="localhost"
fi

# Install APT packages.
if ! command -v npm >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y jq nano npm
fi

PECL_UPDATED=false
# Install APCU extension. Bypass question about enabling internal debugging.
if ! php --re apcu > /dev/null 2>&1; then
  $PECL_UPDATED || sudo pecl update-channels && PECL_UPDATED=true
  sudo pecl install apcu <<< ''
  echo 'extension=apcu.so' | sudo tee /usr/local/etc/php/conf.d/apcu.ini
fi
# Install uploadprogress extension.
if ! php --re uploadprogress > /dev/null 2>&1; then
  $PECL_UPDATED || sudo pecl update-channels && PECL_UPDATED=true
  sudo pecl install uploadprogress
  echo 'extension=uploadprogress.so' | sudo tee /usr/local/etc/php/conf.d/uploadprogress.ini
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
    sudo rm -f /etc/apt/sources.list.d/pgdg.list
  elif [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates
    sudo install -d /usr/share/postgresql-common/pgdg
    sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
    . /etc/os-release
    sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  fi
  time sudo apt-get update

  #== Install postgresql on the host.
  echo "PostgreSQL $PG_MAJOR is not installed. Installing it now."
  time sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "postgresql-$PG_MAJOR" "postgresql-$PG_MAJOR-pgvector" "postgresql-client-$PG_MAJOR"
fi
#== Make it less promiscuous in DDEV only.
if env | grep -q DDEV_PROJECT; then
  sudo chmod 0755 /usr/bin
  sudo chmod 0755 /usr/sbin
  #== Start the PostgreSQL service.
  env PATH="/usr/sbin:/usr/bin:/sbin:/bin" sudo service postgresql start
else
  #== Check if the /var/www/html/postgresql directory doesn't exist.
  #if [ ! -d /var/www/html/postgresql ]; then
  #  echo 'Moving the PostgreSQL data directory to /var/www/html/postgresql.'
  #  #== We need to reset the postgres location to the stored disk location on devpanel.
  #  sudo service postgresql stop
  #  #== Copy the postgresql.conf to the location.
  #  sudo cp ./.devpanel/conf/postgresql.conf /etc/postgresql/17/main/postgresql.conf
  #  #== Fix ownership and permissions.
  #  sudo chown postgres:postgres /etc/postgresql/17/main/postgresql.conf
  #  sudo chmod 0644 /etc/postgresql/17/main/postgresql.conf
  #
  #  #== Make the needed directories.
  #  sudo mkdir -p /var/www/html/postgresql/etc/17/main/
  #  sudo mkdir -p /var/www/html/postgresql/17/
  #
  #  #== Copy the data.
  #  sudo cp -r /var/lib/postgresql/17/main/ /var/www/html/postgresql/17/
  #
  #  #== Copy the files from the original location.
  #  sudo cp /etc/postgresql/17/main/pg_hba.conf /var/www/html/postgresql/etc/17/main/
  #
  #  #== Set ownership and permissions.
  #  sudo chown -R postgres:postgres /var/www/html/postgresql/
  #  sudo chmod 0700 -R /var/www/html/postgresql/17/main
  #
  #== Start the postgresql service.
  sudo service postgresql start
  #== Create the user and database if the image did not already provide them.
  if [ "$(sudo su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname = 'db'\"")" != 1 ]; then
    sudo su postgres -c "psql -c \"CREATE ROLE db WITH LOGIN PASSWORD 'db';\""
  fi
  if [ "$(sudo su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname = 'db'\"")" != 1 ]; then
    sudo su postgres -c "psql -c \"CREATE DATABASE db WITH OWNER db ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;\""
  fi
  #== Enable pgvector extension.
  sudo su postgres -c "psql -d db -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
  #else
  #  echo 'PostgreSQL is already installed - starting.'
  #  sudo service postgresql start
  #fi
fi

# Make sure that php has pgsql installed.
if ! php --re pgsql > /dev/null 2>&1; then
  sudo apt-get install -y libpq-dev
  sudo -E docker-php-ext-install pgsql
fi

# Reload Apache if it's running.
if $PECL_UPDATED && sudo /etc/init.d/apache2 status > /dev/null; then
  sudo /etc/init.d/apache2 reload
fi
