#!/usr/bin/env bash

drush cr
#== Apply the admin toolbar.
drush pm:en admin_toolbar -y
drush pm:en admin_toolbar_tools -y

#== Apply the recipe with variables.
drush recipe ../recipes/drupal_module_chatbot_recipe -y

#== Get all the nodes.
drush pbai

echo "Making sure the tiktoken directory is writable by all users..."
#== Make sure tiktoken is writable by all.
if [ ! -d /tmp/tiktoken ]; then
  sudo mkdir -p /tmp/tiktoken
fi
sudo chmod -R 777 /tmp/tiktoken

#== Flush the caches.
echo
echo 'Flush the caches.'
time drush cr

#== Index 10 nodes per time for 5600 nodes.
for i in {1..560}; do
  drush sapi-i --limit=10 modules_index
  echo "Indexed 10 nodes, iteration $i"
  #== Sleep for 2 second to avoid overloading the system.
  sleep 2
done
