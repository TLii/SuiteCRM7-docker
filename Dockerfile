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



# Base image
FROM debian:bullseye-slim as base
RUN set -eux; \
    apt update && apt -y upgrade; \
    apt install -y --no-install-recommends \
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
    git checkout master;



# Get Composer binary to use in other images
FROM composer:1 AS composer



# Build with composer
FROM base as build-php
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /build
ARG COMPOSER_ALLOW_SUPERUSER 1

RUN composer install --no-dev;



# Create finalized image to be used 
FROM base as final

RUN mv /build /final

# Copy processed artifacts to final image
COPY --from=build-php /build/vendor /final/vendor

# Build an image that can be used as base image for further development
FROM debian:bullseye-slim as base-final
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
    SUITECRM_INSTALL_DIR=/suitecrm \
    SUITECRM_SITE_NAME=SuiteCRM \
    SUITECRM_SITE_URL=example.com \
    SUITECRM_CONFIG_LOC=${SUITECRM_INSTALL_DIR}/docker-configs

# Install modules, clean up and modify values
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
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
    mkdir ${SUITECRM_INSTALL_DIR} || echo "Installation directory ${SUITECRM_INSTALL_DIR} exists" ; \
    mkdir /docker-configs && chown www-data:www-data /docker-configs

    # Ensure we are installing on a volume
    VOLUME ${SUITECRM_INSTALL_DIR}

    # Copy data for final image
    COPY docker-entrypoint.sh /docker-entrypoint.sh
    COPY --from=final --chown=www-data:www-data /final /usr/src/suitecrm
    COPY --chown=www-data:www-data config_si.php /tmp

    RUN chmod a+x /docker-entrypoint.sh;

    WORKDIR ${SUITECRM_INSTALL_DIR}

# Run final image with php-fpm
FROM php:fpm AS serve-php-fpm
LABEL App=SuiteCRM7
EXPOSE 9000

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
    SUITECRM_INSTALL_DIR=/suitecrm \
    SUITECRM_SITE_NAME=SuiteCRM \
    SUITECRM_SITE_URL=example.com \
    SUITECRM_CONFIG_LOC=${SUITECRM_INSTALL_DIR}/docker-configs

# Install modules, clean up and modify values
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
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
    # Use uid and gid of www-data used in nginx image
    usermod -u 101 www-data && groupmod -g 101 www-data; \
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    # Make install dir and separate directory for configs. Entrypoint will link them.
    mkdir ${SUITECRM_INSTALL_DIR} || echo "Installation directory ${SUITECRM_INSTALL_DIR} exists" ; \
    mkdir /docker-configs && chown www-data:www-data /docker-configs

# Ensure we are installing on a volume
VOLUME ${SUITECRM_INSTALL_DIR}

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final --chown=www-data:www-data /final /usr/src/suitecrm
COPY --chown=www-data:www-data config_si.php /tmp

RUN chmod a+x /docker-entrypoint.sh;

WORKDIR ${SUITECRM_INSTALL_DIR}

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]

# Run final image with apache2 and php
FROM php:apache as serve-php-apache2
LABEL App=SuiteCRM7
EXPOSE 80

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
    SUITECRM_INSTALL_DIR=/suitecrm \
    SUITECRM_SITE_NAME=SuiteCRM \
    SUITECRM_SITE_URL=example.com \
    SUITECRM_CONFIG_LOC=/docker-configs

# Install modules, clean up and modify values
RUN apt update && apt -y upgrade; \
    #
    # Install dependencies #
    apt -y install \
    cron \
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
    # Use uid and gid of www-data used in nginx image
    usermod -u 101 www-data && groupmod -g 101 www-data; \
    # Use php production config
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    # Make install dir and separate directory for configs. Entrypoint will link them.
    mkdir ${SUITECRM_INSTALL_DIR} || echo "Directory ${SUITECRM_INSTALL_DIR}} exists"; \
    chown www-data:www-data ${SUITECRM_INSTALL_DIR}; \
    mkdir /docker-configs && chown www-data:www-data /docker-configs


VOLUME ${SUITECRM_INSTALL_DIR}

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=final --chown=www-data:www-data /final /usr/src/suitecrm
COPY --chown=www-data:www-data config_si.php /tmp

# Use uid and gid of www-data used in nginx image
RUN chmod a+x /docker-entrypoint.sh;

WORKDIR ${SUITECRM_INSTALL_DIR}

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD [ "apache2-foreground" ]
