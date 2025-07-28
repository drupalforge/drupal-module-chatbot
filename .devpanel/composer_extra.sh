#!/usr/bin/env bash
set -eu -o pipefail
cd $APP_ROOT

# Currently the recipe is beta.
composer config minimum-stability dev

# Also get admin toolbar
composer require drupal/admin_toolbar

# Install the dependencies of the recipe.
composer require drupal/ai:^1.1.0 drupal/ai_agents:^1.1.0 drupal/ai_provider_litellm:^1.1.0 drupal/ai_vdb_provider_postgres:^1.0@alpha drupal/search_api:^1.38 league/commonmark:^2.4 drupal/pb_ai:^1.0@beta drupal/login_destination:^2.0@beta

# Copy the recipe into recipes.
if [ ! -d recipes ]; then
  mkdir recipes
fi

  # Get AI Image Alt Text
composer require drupal/ai_image_alt_text

cp -r drupal_module_chatbot_recipe recipes/
