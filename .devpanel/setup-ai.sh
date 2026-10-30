if [ -n "${DP_AI_VIRTUAL_KEY:-}" ]; then
  time drush pm:en -y ai ai_provider_litellm
  echo
  drush -n key-save litellm_api_key --label="LiteLLM API key" --key-provider=env --key-provider-settings='{
    "env_variable": "DP_AI_VIRTUAL_KEY",
    "base64_encoded": false,
    "strip_line_breaks": true
  }'
  drush -n cset ai_provider_litellm.settings api_key litellm_api_key
  drush -n cset ai_provider_litellm.settings moderation false --input-format yaml
  drush -n cset ai_provider_litellm.settings host "https://ai.drupalforge.org"
  drush -n cset ai_provider_openai.settings api_key openai_api_key
  drush -n cset ai.settings default_providers.chat.provider_id litellm
  drush -n cset ai.settings default_providers.chat.model_id openai/gpt-4.1-mini
  drush -n cset ai.settings default_providers.chat_with_complex_json.provider_id litellm
  drush -n cset ai.settings default_providers.chat_with_complex_json.model_id openai/gpt-4.1-mini
  drush -n cset ai.settings default_providers.chat_with_image_vision.provider_id litellm
  drush -n cset ai.settings default_providers.chat_with_image_vision.model_id openai/gpt-4.1-mini
  drush -n cset ai.settings default_providers.chat_with_structured_response.provider_id litellm
  drush -n cset ai.settings default_providers.chat_with_structured_response.model_id openai/gpt-4.1-mini
  drush -n cset ai.settings default_providers.chat_with_tools.provider_id litellm
  drush -n cset ai.settings default_providers.chat_with_tools.model_id openai/gpt-4.1-mini
  drush -n cset ai.settings default_providers.embeddings.provider_id litellm
  drush -n cset ai.settings default_providers.embeddings.model_id openai/text-embedding-3-small
  drush -n cset ai.settings default_providers.text_to_speech.provider_id litellm
  drush -n cset ai.settings default_providers.text_to_speech.model_id openai/gpt-4o-mini-realtime-preview

  # Print out the whole configuration for debugging.
  echo "AI configuration:"
  drush cget ai.settings --format=yaml
  echo
  # Check if psql is installed.
  if command -v psql >/dev/null 2>&1; then
    if env | grep -q DDEV_PROJECT; then
      VDB_HOST=$PG_HOST
    else
      VDB_HOST=localhost
    fi
    # The container startup script may still be installing PostgreSQL.
    echo "Waiting for PostgreSQL at $VDB_HOST:5432..."
    for _ in $(seq 1 300); do
      pg_isready --quiet --host="$VDB_HOST" --port=5432 && break
      sleep 2
    done
    if ! pg_isready --host="$VDB_HOST" --port=5432; then
      echo "PostgreSQL did not become available. See /tmp/custom_package_installer.log." >&2
      exit 1
    fi
    time drush pm:en -y ai_vdb_provider_postgres ai_search
    drush -n key-save postgres_db_password --label="Postgres DB Password" --key-provider=config --key-provider-settings='{
      "key_value": "db"
    }'
    drush -n cset ai_vdb_provider_postgres.settings password postgres_db_password
    drush -n cset ai_vdb_provider_postgres.settings host "$VDB_HOST"
    drush -n cset ai_vdb_provider_postgres.settings port 5432
    drush -n cset ai_vdb_provider_postgres.settings default_database db
    drush -n cset ai_vdb_provider_postgres.settings username db
  fi

  # Flush the cache.
  drush cr
fi
