#!/usr/bin/env bash

setup_php_user(){
    # Setup correct user; (c) Docker, Inc
	if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ]; then
		uid="$(id -u)"
		gid="$(id -g)"
		if [ "$uid" = '0' ]; then
			case "$1" in
				apache2*)
					user="${APACHE_RUN_USER:-www-data}"
					group="${APACHE_RUN_GROUP:-www-data}"

					# strip off any '#' symbol ('#1000' is valid syntax for Apache)
					pound='#'
					user="${user#$pound}"
					group="${group#$pound}"
					;;
				*) # php-fpm
					user='www-data'
					group='www-data'
					;;
			esac
		else
			user="$uid"
			group="$gid"
		fi
	fi
	export user=$user
	export group=$group
}

php_entrypoint() {
		# Wrap up with executing correct process with correct arguments
    if [[ "$1" == apache2* ]] && [ "${1#-}" != "$1" ]; then
        set -- apache2-foreground "$@"
    elif [ "${1#-}" != "$1" ]; then
        set -- php-fpm "$@"
    fi

    exec "$@"
}