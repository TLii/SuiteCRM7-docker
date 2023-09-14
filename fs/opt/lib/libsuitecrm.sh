#!/usr/bin/env bash

check_app_variables() {
	# @prepare_env()
	# Test for necessary environment variables and exit if missing crucial ones.
	[[ -z $SUITECRM_DATABASE_NAME ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_NAME to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_USER ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_USER to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_PASSWORD ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_PASSWORD to continue"; exit 78)
	[[ -z $SUITECRM_DATABASE_HOST ]] && (echo "ERROR: you need to set SUITECRM_DATABASE_HOST to continue"; exit 78)
	[[ -z $SUITECRM_SITE_URL ]] && (echo "ERROR: you need to set SUITECRM_SITE_URL to continue"; exit 78)

	# Add certain environment variables
	export SUITECRM_INSTALL_DIR=$PWD; # Installation directory has been determined by Dockerfile and set as WORKDIR.
	[[ -z "$SUITECRM_CONFIG_LOC" ]] && export SUITECRM_CONFIG_LOC="/docker-configs"; # Config mountable location
}

set_apache_config() {
	# @setup_dependencies
	# Create necessary apache2 config changes to maintain directory similarities
	if [[ "$1" == apache2* ]]; then
		sed -i -e "s|www\.example\.com|$SUITECRM_SITE_URL|g" -e "s|var/www/html|$SUITECRM_INSTALL_DIR|g" -e "s|localhost|$SUITECRM_SITE_URL|g" /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-available/default-ssl.conf;
		sed -i "s|var/www/html|$SUITECRM_INSTALL_DIR|g" /etc/apache2/conf-available/docker-php.conf;
	fi
}

test_and_copy() {
	# @prepare_app

  # Test for existing installation and install as necessary
	if [ ! -e "/$SUITECRM_INSTALL_DIR/config.php" ] && [ ! -e "/$SUITECRM_INSTALL_DIR/VERSION" ]; then
		# Copy files, if seemingly not installed.
		copy_files && install_needed=1
	elif [[ -z $SUITECRM_IGNORE_VERSION ]]; then
		# If installed and version is not ignored, update.
		copy_files
		update_modules && rebuild_needed=1
	fi

	if [[ $install_needed == 1 && -z $SUITECRM_MANUAL_INSTALL ]]; then
		echo "Running silent install..." >&1;
		suitecrm_install
	elif [[ rebuild_needed -eq 1 && -z $SUITECRM_MANUAL_UPGRADE ]] ; then
		echo >&2 "Upgraded files. Now rebuilding..."
		suitecrm_rebuild
	else
		echo >&2 "Not upgrading."
	fi

}

check_suitecrm_config() {
	# @ prepare_app
	# Check if config.php and config_override.php are locally in installation directory or in external location, and if latter, link them. Local files take precedence over linking.
	[[ -f "$SUITECRM_CONFIG_LOC/config.php" ]] && [[ ! -f "$SUITECRM_INSTALL_DIR/config.php" ]] && ln -s "$SUITECRM_CONFIG_LOC/config.php" "$SUITECRM_INSTALL_DIR/"
	[[ -f "$SUITECRM_CONFIG_LOC/config_override.php" ]] && [[ ! -f "$SUITECRM_INSTALL_DIR/config_override.php" ]] && ln -s "$SUITECRM_CONFIG_LOC/config_override.php" "$SUITECRM_INSTALL_DIR/"
}

copy_files() {
	# Ref: test_and_copy()
	cd "$SUITECRM_INSTALL_DIR" || exit 1

    # Correct permissions if necessary
	if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
		chown "$user:$group" .
	fi

	echo >&2 "SuiteCRM not found in $PWD - copying now..."
	if [ -n "$(find . -mindepth 1 -maxdepth 1)" ]; then
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
		/usr/src/suitecrm/custom/modules/* \
		/usr/src/suitecrm/custom/Extension/* \
		/usr/src/suitecrm/modules/* \
	; do
		# Check if contentPath exists. Only non-existing files will be copied.
		contentPath="${contentPath%/}"
		[ -e "$contentPath" ] || continue
		# If contentPath exists in source and application directory, exclude it from overwrite
		# We'll update such content to newer versions later on
		contentPath="${contentPath#/usr/src/suitecrm/}"
		if [ -e "$PWD/$contentPath" ]; then
			echo >&1 "INFO: '$PWD/$contentPath' exists. Updating only with newer content."
			sourceTarArgs+=( --exclude "./$contentPath" )
		fi
	done

	tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
	echo >&2 "Copying complete. Now updating modules..."
	echo >&2 "Complete! SuiteCRM has been successfully copied to $PWD"
}

update_modules() {
	# Ref: test_and_copy()
	modules_updated=0
	# See if modules need updating; save backups to <install_dir>/upload/docker-upgrade-backups/
	mkdir -p "$PWD"/upload/docker-upgrade-backups/"$(date +%Y%m%d)"
	for modulePath in \
		/usr/src/suitecrm/custom/modules/* \
		/usr/src/suitecrm/modules/* \
	; do
		modulePath="${modulePath#/usr/src/suitecrm/}"
		## Ignore all with /ext/, but not custom/Extension/*/Ext/. Kudos @pgr!
		rsync -q -r -b -t -u --backup-dir="$PWD"/upload/docker-upgrade-backups --update --exclude "$modulePath"/ext/* --exclude "$modulePath"/*/ext/* /usr/src/suitecrm/"$modulePath" "$PWD"/"$modulePath"
		modules_updated=1
		echo "$modulePath" has been updated, and backup has been saved in "$PWD"/upload/docker-upgrade-backups/"$(date +%Y%m%d)"
	done
	if [[ modules_updated -eq 1 ]]; then
		unset modules_updated
		return 1
	fi
}

suitecrm_install() {
	# Ref: test_and_copy()
	# Move silent install configuration to install directory
	mv fs/opt/suitecrm/templates/config_si.php "$SUITECRM_INSTALL_DIR"/
    php -r "\$_SERVER['HTTP_HOST'] = 'localhost'; \$_SERVER['REQUEST_URI'] = '$SUITECRM_INSTALL_DIR/install.php';\$_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);require_once '$SUITECRM_INSTALL_DIR/install.php';" >&1;
    touch "$SUITECRM_INSTALL_DIR"/custom/install.lock || (echo "Failed creating install lock" >&2; exit 73);
	chown www-data:www-data "$SUITECRM_INSTALL_DIR"/custom/install.lock
    echo "Installation ready" >&1
}

suitecrm_rebuild() {
	# Ref: test_and_copy()
	# Run Quick Repair and Rebuild
	if  [ "$EUID" -eq 0 ]; then
        su -l www-data -s /bin/bash -c "php /opt/suitecrm/repair.php"
    else
        php /opt/suitecrm/repair.php
    fi
}

suitecrm_install_cleanup() {
	# @finish_cleanup()
	# Clean up afterwards
	[[ -f fs/opt/suitecrm/templates/config_si.php ]] && rm fs/opt/suitecrm/templates/config_si.php
	[[ -f /tmp/cronfile ]] && rm /tmp/cronfile

}

suitecrm_setup_crontab() {
	# @finish_app_setup()
	# Create crontab if configured
  if [[ -n $SUITECRM_CRONTAB_ENABLED ]]; then
    suitecrm_create_crontab || (echo "Failed to create crontab" >&2; exit 70)
    echo "Crontab set" >&1
  else
    echo >&2 "Crontab is not set, please use an external crontab, e.g. a webcron service, to run $SUITECRM_INSTALL_DIR/cron.php at every minute."
  fi
}

suitecrm_create_crontab() {
	# Ref: suitecrm_setup_crontab()
	echo '* * * * * /usr/bin/flock -n /var/lock/crm-cron.lockfile "cd $SUITECRM_INSTALL_DIR;php -f cron.php" > /dev/null 2>&1' >> /tmp/cronfile
	crontab -u www-data /tmp/cronfile && return 1
}
