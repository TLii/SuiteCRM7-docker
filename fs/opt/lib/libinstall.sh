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
}

setup_app() {
  test_and_copy
}

finish_app_setup() {
  suitecrm_setup_crontab
}

finish_cleanup() {
  suitecrm_install_cleanup
}

run_entrypoint() {
  php_entrypoint
}
