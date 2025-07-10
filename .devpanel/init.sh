#!/usr/bin/env bash
: "${DEBUG_SCRIPT:=}"
if [ -n "$DEBUG_SCRIPT" ]; then
  set -x
fi
set -eu -o pipefail
cd $APP_ROOT

# Check if $PG_HOST is set, if not, set it to 'pgvector'.
if [ -z "${PG_HOST:-}" ]; then
  export PG_HOST="localhost"
fi

LOG_FILE="logs/init-$(date +%F-%T).log"
exec > >(tee $LOG_FILE) 2>&1

TIMEFORMAT=%lR
# For faster performance, don't audit dependencies automatically.
export COMPOSER_NO_AUDIT=1
# For faster performance, don't install dev dependencies.
export COMPOSER_NO_DEV=1

#== Remove root-owned files.
echo
echo Remove root-owned files.
time sudo rm -rf lost+found

#== Composer install.
if [ ! -f composer.json ]; then
  echo
  echo 'Generate composer.json.'
  time source .devpanel/composer_setup.sh
  time source .devpanel/composer_extra.sh
fi
echo
time composer -n update --no-dev --no-progress

#== Create the private files directory.
if [ ! -d private ]; then
  echo
  echo 'Create the private files directory.'
  time mkdir private
fi

#== Create the config sync directory.
if [ ! -d config/sync ]; then
  echo
  echo 'Create the config sync directory.'
  time mkdir -p config/sync
fi

#== Generate hash salt.
if [ ! -f .devpanel/salt.txt ]; then
  echo
  echo 'Generate hash salt.'
  time openssl rand -hex 32 > .devpanel/salt.txt
fi

#== Check if the /var/www/html/postgresql directory doesn't exist.
if [ ! -d /var/www/html/postgresql ]; then
  echo 'Moving the PostgreSQL data directory to /var/www/html/postgresql.'
  #== We need to reset the postgres location to the stored disk location on devpanel.
  sudo service postgresql stop
  #== Copy the postgresql.conf to the location.
  sudo cp ./devpanel/conf/postgresql.conf /etc/postgresql/17/main/postgresql.conf
  #== Fix ownership and permissions.
  sudo chown postgres:postgres /etc/postgresql/17/main/postgresql.conf
  sudo chmod 0644 /etc/postgresql/17/main/postgresql.conf

  #== Make the needed directories.
  sudo mkdir -p /var/www/html/postgresql/etc/17/main/
  sudo mkdir -p /var/www/html/postgresql/17/

  #== Copy the data.
  sudo cp -r /var/lib/postgresql/17/main/ /var/www/html/postgresql/17/

  #== Copy the files from the original location.
  sudo cp /etc/postgresql/17/main/pg_hba.conf /var/www/html/postgresql/etc/17/main/

  #== Set ownership and permissions.
  sudo chown -R postgres:postgres /var/www/html/postgresql/
  sudo chmod 0700 -R /var/www/html/postgresql/17/main

  #== Start the postgresql service.
  sudo service postgresql start
  #== Create the user.
  sudo su postgres -c "psql -c \"CREATE ROLE db WITH LOGIN PASSWORD 'db';\""
  #== Create the database.
  sudo su postgres -c "psql -c \"CREATE DATABASE db WITH OWNER db ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;\""
  #== Enable pgvector extension.
  sudo su postgres -c "psql -d db -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
else
  echo 'PostgreSQL is already installed - copying and restarting.'
  sudo cp ./.devpanel/conf/postgresql.conf /etc/postgresql/17/main/postgresql.conf
  sudo chown postgres:postgres /etc/postgresql/17/main/postgresql.conf
  sudo chmod 0644 /etc/postgresql/17/main/postgresql.conf
  sudo service postgresql restart
fi

#== Install Drupal.
echo
NEWINSTALL=0
if [ -z "$(mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASSWORD $DB_NAME -e 'show tables')" ]; then
  time drush -n si

  echo
  echo 'Tell Automatic Updates about patches.'
  drush pm:en package_manager -y
  time drush -n cset --input-format=yaml package_manager.settings additional_known_files_in_project_root '["patches.json", "patches.lock.json"]'
  NEWINSTALL=1
else
  drush -n updb
fi

source .devpanel/setup-ai.sh
#== Apply the recipe logic if its a new install.
if [ $NEWINSTALL -eq 1 ]; then
  source .devpanel/recipe_logic.sh
fi

#== Warm up caches.
echo
echo 'Run cron.'
time drush cron
echo
echo 'Populate caches.'
if ! time drush cache:warm 2> /dev/null; then
  time .devpanel/warm > /dev/null
fi

#== Finish measuring script time.
INIT_DURATION=$SECONDS
INIT_HOURS=$(($INIT_DURATION / 3600))
INIT_MINUTES=$(($INIT_DURATION % 3600 / 60))
INIT_SECONDS=$(($INIT_DURATION % 60))
printf "\nTotal elapsed time: %d:%02d:%02d\n" $INIT_HOURS $INIT_MINUTES $INIT_SECONDS
