#!/usr/bin/env bash

drush cr
#== Apply the admin toolbar.
drush pm:en admin_toolbar -y
drush pm:en admin_toolbar_tools -y

#== Apply the recipe with variables.
drush recipe ../recipes/drupal_module_chatbot_recipe -y

#== Get all the nodes.
drush pbai

#== Index 10 nodes.
drush sapi-i --limit=10 modules_server
