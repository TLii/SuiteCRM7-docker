#!/usr/bin/env bash

run_init() {
  prepare_env "$@"

  # Setup all dependencies
  setup_dependencies "$@"

  # Prepare application install
  prepare_app "$@"

  run_custom_init "$@"
}

run_custom_init() {
  if [[ $(ls -A /opt/custom_scripts/init) ]]; then
    for sc in /opt/custom_scripts/init/*.sh; do bash "$sc"; done
  fi
  # If trigger_custom_init() exists, run it
  if [[ $(type -t trigger_custom_init) == function ]]; then
    trigger_custom_init "$@"
  else
    return
  fi

}

run_setup() {

  prepare_app "$@"

  setup_app "$@"

  run_custom_setup "$@"

}

run_custom_setup() {
  if [[ $(ls -A /opt/custom_scripts/setup) ]]; then
    for sc in /opt/custom_scripts/setup/*.sh; do bash "$sc"; done
  fi
  # If trigger_custom_setup() exists, run it
  if [[ $(type -t trigger_custom_setup) == function ]]; then
    trigger_custom_setup "$@"
  else
    return
  fi

}


run_finish() {

    finish_app_setup "$@"

    finish_cleanup "$@"

    run_custom_finish "$@"
}

run_custom_finish() {
    if [[ $(ls -A /opt/custom_scripts/finish) ]]; then
        for sc in /opt/custom_scripts/finish/*.sh; do bash "$sc"; done
    fi
    # If trigger_custom_finish() exists, run it
    if [[ $(type -t trigger_custom_finish) == function ]]; then
        trigger_custom_finish "$@"
    fi

}

run_entrypoint() {
    if [[ $(ls -A /opt/custom_scripts/entrypoint/) ]]; then
        # If there are scripts under /opt/custom_scripts/entrypoint, run them.
        # Note: results are unpredictable, if there are multiple files in the
        # directory.
        for sc in /opt/custom_scripts/entrypoint/*; do bash "$sc"; done
    elif [[ $(type -t custom_entrypoint) == function ]]; then
        # If set, run custom_entrypoint(), otherwise run default app_entrypoint().
        custom_entrypoint "$@"
    else
        app_entrypoint "$@"
    fi
}