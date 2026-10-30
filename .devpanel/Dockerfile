
# Appended to the Drupal Forge base Dockerfile by docker_publish_action.
USER root

# Defaults to the PostgreSQL client version shipped with the base image.
ARG PG_MAJOR=""
ENV PG_MAJOR=${PG_MAJOR}

# Install tools, PHP extensions, and a PostgreSQL server that matches the
# client version shipped with the base image. The base image already provides
# the PostgreSQL apt repository configuration.
RUN set -eux; \
    PG_MAJOR="${PG_MAJOR:-$(psql --version | grep -oE '[0-9]+' | head -n1)}"; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      jq nano npm \
      "postgresql-${PG_MAJOR}" "postgresql-${PG_MAJOR}-pgvector"; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    pecl channel-update pecl.php.net; \
    printf '\n' | pecl install apcu; \
    pecl install uploadprogress; \
    docker-php-ext-enable apcu uploadprogress; \
    rm -rf /tmp/pear

# Create the vector database used by the chatbot search index.
RUN set -eux; \
    service postgresql start; \
    su postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE ROLE db WITH LOGIN PASSWORD 'db';\""; \
    su postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE DATABASE db WITH OWNER db ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;\""; \
    su postgres -c "psql -v ON_ERROR_STOP=1 -d db -c 'CREATE EXTENSION IF NOT EXISTS vector;'"; \
    service postgresql stop

USER ${USER}
