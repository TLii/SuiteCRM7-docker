#!/usr/bin/env bash

# Unofficial SuiteCRM 7 containers
# Copyright (C) 2022 Tuomas Liinamaa <tlii@iki.fi>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# Partially derived from Docker Hub's official images; 
# Copyright 2014 Docker, Inc.set -e

set -Eeuo pipefail

user=www-data
group=www-data

# Test for necessary environment variables and exit if missing crucial ones.
	[[ -z $SUITECRM_DATABASE_NAME ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_NAME to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_USER ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_USER to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_PASSWORD ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_PASSWORD to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_HOST ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_HOST to continue"; exit 78)
	[[ -z $SUITECRM_SITE_URL ]] && (echo "ERROR: you need to set SUITECRM_SITE_URL to continue"; exit 78)


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

# Create necessary apache2 config changes to maintain directory similarities
	if [[ "$1" == apache2* ]]; then
		sed -i -e "s/www\.example\.com/$SUITECRM_SITE_URL/g" -e "s/var\/www\/html/$SUITECRM_INSTALL_DIR/g" -e "s/localhost/$SUITECRM_SITE_URL/g" /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-available/default-ssl.conf;
		sed -i "s/var\/www\/html/$SUITECRM_INSTALL_DIR/g" /etc/apache2/conf-available/docker-php.conf;
	fi

([[ -f $SUITECRM_INSTALL_DIR/docker-configs/config.php ]] && [[ ! -f $SUITECRM_INSTALL_DIR/config.php ]]) && ln -s $SUITECRM_INSTALL_DIR/docker-configs/config.php $SUITECRM_INSTALL_DIR/config.php
([[ -f $SUITECRM_INSTALL_DIR/docker-configs/config_override.php ]] && [[ ! -f $SUITECRM_INSTALL_DIR/config_override.php ]]) && ln -s $SUITECRM_INSTALL_DIR/docker-configs/config_override.php $SUITECRM_INSTALL_DIR/config_override.php
([[ -f $SUITECRM_INSTALL_DIR/docker-configs/config_si.php ]] && [[ ! -f $SUITECRM_INSTALL_DIR/config.php ]]) && ln -s $SUITECRM_INSTALL_DIR/docker-configs/config_si.php $SUITECRM_INSTALL_DIR/config_si.php

# Test for existing installation and install as necessary; original code by Docker, Inc, edited by TLii
if [ ! -e /$SUITECRM_INSTALL_DIR/config.php ] && [ ! -e /$SUITECRM_INSTALL_DIR/VERSION ]; then

    cd "$SUITECRM_INSTALL_DIR"

    # Correct permissions if necessary
	if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
		chown "$user:$group" .
	fi

	echo >&2 "SuiteCRM not found in $PWD - copying now..."
	if [ -n "$(find . -mindepth 1 -maxdepth 1 -not -name docker-configs)" ]; then
		echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
	fi

	sourceTarArgs=(
		--create
		--file -
		--directory /usr/src/suitecrm
		--owner "$user" --group "$group"
	)
	targetTarArgs=(
		--extract
		--file -
	)
	if [ "$uid" != '0' ]; then
		# avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
		targetTarArgs+=( --no-overwrite-dir )
	fi
	# loop over modular content in the source, and if it already exists in the destination, exclude it
	for contentPath in \
		/usr/src/suitecrm/custom/*/* \
		/usr/src/suitecrm/modules/* \
	; do
		# Check if contentPath exists
		contentPath="${contentPath%/}"
		[ -e "$contentPath" ] || continue
		# If contentPath exists in source and application directory, exclude it from overwrite
		contentPath="${contentPath#/usr/src/suitecrm/}"
		if [ -e "$PWD/$contentPath" ]; then
			echo >&2 "WARNING: '$PWD/$contentPath' exists. Not overwriting with container version." 
			#TODO: Make this check if update is in fact newer and patchable.
			sourceTarArgs+=( --exclude "./$contentPath" )
		fi
	done
	tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
	echo >&2 "Complete! SuiteCRM has been successfully copied to $PWD"
fi

# Use install.lock to check if already installed
if [[ ! -f $SUITECRM_INSTALL_DIR/custom/install.lock ]] && [[ -n $SUITECRM_SILENT_INSTALL ]]; then
    echo "Running silent install..." >&1;
    php -r "\$_SERVER['HTTP_HOST'] = 'localhost'; \$_SERVER['REQUEST_URI'] = '$SUITECRM_INSTALL_DIR/install.php';\$_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);require_once '$SUITECRM_INSTALL_DIR/install.php';" >&1; 
    touch $SUITECRM_INSTALL_DIR/custom/install.lock || (echo "Failed creating install lock" >&2; exit 73);
    echo "Installation ready" >&1
fi

# Create crontab
echo '* * * * * /usr/bin/flock -n /var/lock/crm-cron.lockfile "cd /var/www/html;php -f cron.php" > /dev/null 2>&1' >> /tmp/cronfile
crontab -u www-data /tmp/cronfile || (echo "Failed to create crontab" >&2; exit 70)
rm /tmp/cronfile
echo "Crontab set" >&1


# Wrap up with executing correct process with correct arguments
if [[ "$1" == apache2* ]] && [ "${1#-}" != "$1" ]; then
	set -- apache2-foreground "$@"
elif [ "${1#-}" != "$1" ]; then
	set -- php-fpm "$@"
fi

exec "$@"