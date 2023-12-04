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

## ARGUMENTS

ARG DEBIAN_VERSION=12.1 \
    COMPOSER_VERSION=1 \
    PHP_VERSION=8.2 \
    SUITECRM_CONFIG_LOC=/docker-configs


## INITIAL BUILD
# Create initial base image
FROM debian:${DEBIAN_VERSION}-slim as first
RUN set -eux; \
    apt-get update && apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
    curl \
    git \
    gnupg \
    php-cli \
    php-curl \
    php-intl \
    php-gd \
    php-mbstring \
    php-mysql \
    php-soap \
    php-xml \
    php-zip \
    php-imap \
    php-ldap \
    unzip \
    ca-certificates \
    ; \
    mkdir /build;

WORKDIR /build

# Get source and use latest master
RUN git clone https://github.com/salesagility/SuiteCRM.git .; \
    git checkout hotfix;



# Get Composer binary to use in other images
FROM composer:$COMPOSER_VERSION AS composer



# Run composer install to get dependencies
FROM first as build-php
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /build
ARG COMPOSER_ALLOW_SUPERUSER 1

RUN composer install --no-dev;



# Finalize build
FROM first as final

RUN mv /build /final

# Copy processed artifacts to final image
COPY --from=build-php /build/vendor /final/vendor

# Run final image with php-fpm
FROM php:${PHP_VERSION}-fpm AS fpm
LABEL app="SuiteCRM7"
EXPOSE 9000
USER root
# Environment variables.
ENV \
    SUITECRM_DATABASE_COLLATION=utf8_general_ci \
    SUITECRM_DATABASE_DROP_TABLES=0 \
    SUITECRM_DATABASE_HOST_INSTANCE=SQLEXPRESS \
    SUITECRM_DATABASE_HOST=localhost \
    SUITECRM_DATABASE_NAME=suitecrm \
    SUITECRM_DATABASE_PASSWORD=changeme \
    SUITECRM_DATABASE_PORT=3306 \
    SUITECRM_DATABASE_TYPE=mysql \
    SUITECRM_DATABASE_USE_SSL=false \
    SUITECRM_DATABASE_USER_IS_PRIVILEGED=false \
    SUITECRM_DATABASE_USER=dbuser \
    SUITECRM_DEFAULT_CURRENCY_ISO4217=EUR \
    SUITECRM_DEFAULT_CURRENCY_NAME=Euro \
    SUITECRM_DEFAULT_CURRENCY_SIGNIFICANT_DIGITS=2\
    SUITECRM_DEFAULT_CURRENCY_SYMBOL=€ \
    SUITECRM_DEFAULT_DATE_FORMAT="d.m.y" \
    SUITECRM_DEFAULT_DECIMAL_SEPERATOR="," \
    SUITECRM_DEFAULT_LANGUAGE=en_US \
    SUITECRM_DEFAULT_NUMBER_GROUPING_SEPARATOR=" " \
    SUITECRM_DEFAULT_TIME_FORMAT="H:i" \
    SUITECRM_DEFAULT_EXPORT_CHARSET=UTF-8 \
    SUITECRM_EXPORT_DELIMITER=',' \
    SUITECRM_DEFAULT_LOCALE_NAME_FORMAT="s f l" \
    SUITECRM_SETUP_CREATE_DATABASE=0 \
    SUITECRM_SETUP_DEMO_DATA=false \
    SUITECRM_ADMIN_PASSWORD=changeme753 \
    SUITECRM_ADMIN_USER=admin123 \
    SUITECRM_HOSTNAME=localhost \
    SUITECRM_SITE_NAME=SuiteCRM \
    SUITECRM_SITE_URL=example.com \
    SUITECRM_INSTALL_DIR=/suitecrm \
    SUITECRM_INSTALLED=false

# Install modules, clean up and modify values
RUN apt-get update && apt-get -y upgrade; \
    #
    # Install dependencies #
    apt-get -y install --no-install-recommends \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libc-client-dev \
    libkrb5-dev \
    rsync \
    openssl \
    curl \
    ; \
    #
    # Install php modules #
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j$(nproc) gd; \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install imap; \
    docker-php-ext-install -j$(nproc) mysqli; \
    docker-php-ext-install -j$(nproc) zip; \
    docker-php-ext-install -j$(nproc) bcmath; \
    #
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*;    mkdir -p /var/log/suitecrm; \
    ln -sf /dev/stdout /var/log/suitecrm/suitecrm.log; \
    #
    # Modify settings #
    #
    # Use uid and gid of www-data used in nginx image while removing conflicting username
    userdel Debian-exim && usermod -u 101 www-data && groupmod -g 101 www-data; \
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    # Make install dir and separate directory for configs. Entrypoint will link them.
    mkdir /suitecrm || echo "Installation directory /suitecrm exists" ; \
    mkdir /docker-configs && chown www-data:www-data /docker-configs

# Ensure we are installing on a volume
VOLUME /suitecrm

COPY fs /
COPY --from=final --chown=www-data:www-data /final /usr/src/suitecrm

# Prepare container scripts
RUN chmod a+x /docker-entrypoint.sh; \
    chmod a+x /docker-cron.sh; \
    chmod a+rx /opt/*/*.sh;

WORKDIR /suitecrm
USER 33:33
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]

# Run final image with apache2 and php
FROM php:${PHP_VERSION}-apache as apache2
LABEL app="SuiteCRM7"
EXPOSE 80
USER root:root
# Environment variables.
ENV \
    SUITECRM_DATABASE_COLLATION=utf8_general_ci \
    SUITECRM_DATABASE_DROP_TABLES=0 \
    SUITECRM_DATABASE_HOST_INSTANCE=SQLEXPRESS \
    SUITECRM_DATABASE_HOST=localhost \
    SUITECRM_DATABASE_NAME=suitecrm \
    SUITECRM_DATABASE_PASSWORD=changeme \
    SUITECRM_DATABASE_PORT=3306 \
    SUITECRM_DATABASE_TYPE=mysql \
    SUITECRM_DATABASE_USE_SSL=false \
    SUITECRM_DATABASE_USER_IS_PRIVILEGED=false \
    SUITECRM_DATABASE_USER=dbuser \
    SUITECRM_DEFAULT_CURRENCY_ISO4217=EUR \
    SUITECRM_DEFAULT_CURRENCY_NAME=Euro \
    SUITECRM_DEFAULT_CURRENCY_SIGNIFICANT_DIGITS=2\
    SUITECRM_DEFAULT_CURRENCY_SYMBOL=€ \
    SUITECRM_DEFAULT_DATE_FORMAT="d.m.y" \
    SUITECRM_DEFAULT_DECIMAL_SEPERATOR="," \
    SUITECRM_DEFAULT_LANGUAGE=en_US \
    SUITECRM_DEFAULT_NUMBER_GROUPING_SEPARATOR=" " \
    SUITECRM_DEFAULT_TIME_FORMAT="H:i" \
    SUITECRM_DEFAULT_EXPORT_CHARSET=UTF-8 \
    SUITECRM_EXPORT_DELIMITER=',' \
    SUITECRM_DEFAULT_LOCALE_NAME_FORMAT="s f l" \
    SUITECRM_SETUP_CREATE_DATABASE=0 \
    SUITECRM_SETUP_DEMO_DATA=false \
    SUITECRM_ADMIN_PASSWORD=changeme753 \
    SUITECRM_ADMIN_USER=admin123 \
    SUITECRM_HOSTNAME=localhost \
    SUITECRM_SITE_NAME=SuiteCRM \
    SUITECRM_SITE_URL=example.com \
    SUITECRM_INSTALL_DIR=/suitecrm \
    SUITECRM_INSTALLED=false

# Install modules, clean up and modify values
RUN apt-get update && apt-get -y upgrade; \
    #
    # Install dependencies #
    apt-get -y install --no-install-recommends\
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libc-client-dev \
    libkrb5-dev \
    rsync \
    openssl \
    curl \
    ; \
    #
    # Install php modules #
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j$(nproc) gd; \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install imap; \
    docker-php-ext-install -j$(nproc) mysqli; \
    docker-php-ext-install -j$(nproc) zip; \
    docker-php-ext-install -j$(nproc) bcmath; \
    #
    # Clean up afterwards #
    apt-get -y autoremove; \
    apt-get -y clean; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*;    mkdir -p /var/log/suitecrm; \
    ln -sf /dev/stdout /var/log/suitecrm/suitecrm.log; \
    #
    # Modify settings #
    #
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    # Make install dir and separate directory for configs. Entrypoint will link them.
    mkdir /suitecrm || echo "Directory /suitecrm} exists"; \
    chown www-data:www-data /suitecrm; \
    mkdir /docker-configs && chown www-data:www-data /docker-configs


VOLUME /suitecrm

COPY fs /
COPY --from=final --chown=www-data:www-data /final /usr/src/suitecrm

# Prepare container scripts
RUN chmod a+x /docker-entrypoint.sh; \
    chmod a+x /docker-cron.sh; \
    chmod a+rx /opt/*/*.sh;

WORKDIR /suitecrm

USER 33:33

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD [ "apache2-foreground" ]
