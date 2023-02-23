#!/usr/bin/env bash

# SuiteCRM installation script, installation library
# Copyright (c) Tuomas Liinamaa <tlii@iki.fi> 2023

prepare_env() {
  export user=www-data
  export group=www-data
  check_app_variables
}

setup_dependencies() {
  set_apache_config "$@"
  setup_php_user "$@"
}


prepare_app() {
  check_suitecrm_config
  test_and_copy
}

setup_app() {
  return
}

finish_app_setup() {
  # Create crontab
  if [[ -n $SUITECRM_CRONTAB_ENABLED ]]; then
    suitecrm_create_crontab || (echo "Failed to create crontab" >&2; exit 70)
    echo "Crontab set" >&1
  else
    echo >&2 "Crontab is not set, please use an external crontab, e.g. a webcron service, to run $SUITECRM_INSTALL_DIR/cron.php at every minute."
fi
}

finish_cleanup() {
  return
}

run_entrypoint() {
  php_entrypoint
}
