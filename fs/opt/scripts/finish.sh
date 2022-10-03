#!/usr/bin/env bash

entry_finish() {
    # Wrap up with executing correct process with correct arguments
    if [[ "$1" == apache2* ]] && [ "${1#-}" != "$1" ]; then
        set -- apache2-foreground "$@"
    elif [ "${1#-}" != "$1" ]; then
        set -- php-fpm "$@"
    fi

    exec "$@"
}