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

#!/usr/bin/env bash

#Update.
time sudo apt-get update

# Prepare so it works in devpanel also.
sudo apt -y install curl ca-certificates apt-transport-https
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
. /etc/os-release
sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
sudo apt-get update

#== Install postgresql on the host.
echo 'PostgreSQL is not installed. Installing it now.'
time sudo apt-get install -y postgresql postgresql-17-pgvector postgresql-client
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
  #== Create the user.
  sudo su postgres -c "psql -c \"CREATE ROLE db WITH LOGIN PASSWORD 'db';\""
  #== Create the database.
  sudo su postgres -c "psql -c \"CREATE DATABASE db WITH OWNER db ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;\""
  #== Enable pgvector extension.
  sudo su postgres -c "psql -d db -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
  #else
  #  echo 'PostgreSQL is already installed - starting.'
  #  sudo service postgresql start
  #fi
fi

# Make sure that php has pgsql installed.
sudo apt install -y libpq-dev
sudo -E docker-php-ext-install pgsql

# Reload Apache if it's running.
if $PECL_UPDATED && sudo /etc/init.d/apache2 status > /dev/null; then
  sudo /etc/init.d/apache2 reload
fi
