#!/usr/bin/env bash

drush cr
#== Apply the admin toolbar.
drush pm:en admin_toolbar -y
drush pm:en admin_toolbar_tools -y

#== Apply the recipe with variables.
drush recipe core/recipes/article_content_type
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

#== Index 10 items at a time until nothing is left to index.
remaining_items() {
  drush php:eval 'echo \Drupal\search_api\Entity\Index::load("modules_index")->getTrackerInstance()->getRemainingItemsCount();' 2>/dev/null | tail -n1 || true
}

index_modules() {
  local total remaining previous stalled=0
  total=$(remaining_items)
  if ! [[ "$total" =~ ^[0-9]+$ ]]; then
    echo "Could not determine the number of items to index; skipping indexing."
    return 0
  fi
  remaining=$total
  while [ "$remaining" -gt 0 ]; do
    drush sapi-i --limit=10 modules_index || true
    previous=$remaining
    remaining=$(remaining_items)
    if ! [[ "$remaining" =~ ^[0-9]+$ ]]; then
      echo "Could not determine the number of items left to index; stopping."
      return 0
    fi
    echo "Indexed $((total - remaining)) of $total items ($remaining remaining)."
    #== Stop if indexing makes no progress, e.g. because the backend is failing.
    if [ "$remaining" -ge "$previous" ]; then
      stalled=$((stalled + 1))
      if [ "$stalled" -ge 3 ]; then
        echo "Indexing made no progress after $stalled attempts; stopping."
        return 0
      fi
    else
      stalled=0
    fi
    #== Sleep for 2 seconds to avoid overloading the system.
    sleep 2
  done
  echo "Indexing complete."
}
index_modules
