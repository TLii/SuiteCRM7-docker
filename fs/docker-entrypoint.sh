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

set -Eeo pipefail

export user=www-data
export group=www-data

for sc in /opt/scripts/*.sh; do $sc; done
for sc in /opt/lib/*.sh; do $sc; done

check_app_variables

setup_php_user

set_apache_config

check_suitecrm_config

# Test for existing installation and install as necessary
if [ ! -e "/$SUITECRM_INSTALL_DIR/config.php" ] && [ ! -e "/$SUITECRM_INSTALL_DIR/VERSION" ]; then
    copy_files
elif [[ -n $SUITECRM_UPGRADE_WITH_IMAGE ]]; then
	copy_files
	update_modules && rebuild_needed=1
fi

# Use install.lock to check if already installed
if [[ ! -f $SUITECRM_INSTALL_DIR/custom/install.lock ]]; then
	echo "Running silent install..." >&1;
	suitecrm_install
elif [[ rebuild_needed -eq 1 ]] ; then
	echo >&2 "Upgraded files. Now rebuilding..."
	suitecrm_rebuild
else
	echo >&2 "Installation lock is set, so not installing."
fi


# Create crontab
if [[ -n $SUITECRM_CRONTAB_ENABLED ]]; then
	suitecrm_create_crontab || (echo "Failed to create crontab" >&2; exit 70)
	echo "Crontab set" >&1
else
	echo >&2 "Crontab is not set, please use an external crontab, e.g. a webcron service, to run $SUITECRM_INSTALL_DIR/cron.php at every minute."
fi

entry_finish