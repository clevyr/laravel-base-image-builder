ARG PHP_VERSION
FROM php:$PHP_VERSION-fpm-alpine

ENV LC_ALL=C

WORKDIR /app
VOLUME /app

RUN set -x \
    && apk add --no-cache \
        fcgi \
        git \
        nginx \
        s6 \
    && cd "$PHP_INI_DIR" \
    && sed -ri \
        -e 's/^(access.log)/;\1/' \
        ../php-fpm.d/docker.conf \
    && sed -ri \
        -e 's/;(ping\.path)/\1/' \
        ../php-fpm.d/www.conf \
    && ln -s php.ini-production php.ini \
    && sed -ri \
        -e 's/^(expose_php).*$/\1 = Off/' \
        -e 's/^(memory_limit).*$/\1 = 256M/' \
        php.ini \
    && mkdir /run/nginx

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --from=clevyr/prestissimo /tmp /root/.composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

COPY rootfs/ /

ONBUILD ARG INSTALL_BCMATH
ONBUILD ARG INSTALL_CALENDAR
ONBUILD ARG INSTALL_EXIF
ONBUILD ARG INSTALL_GD
ONBUILD ARG INSTALL_IMAGICK
ONBUILD ARG INSTALL_INTL
ONBUILD ARG INSTALL_MYSQL
ONBUILD ARG INSTALL_OPCACHE
ONBUILD ARG INSTALL_PGSQL
ONBUILD ARG INSTALL_REDIS
ONBUILD ARG INSTALL_SQLSRV
ONBUILD ARG INSTALL_XDEBUG
ONBUILD ARG INSTALL_ZIP
ONBUILD ARG DEPS
ONBUILD ARG INSTALL

ONBUILD RUN \
    if [ "$INSTALL_BCMATH" != "false" ]; then \
        export INSTALL_BCMATH='true'\ 
    ; fi \
    && if [ "$INSTALL_MYSQL" = "true" ]; then \
        export INSTALL_MYSQLI='true' \
            INSTALL_PDO_MYSQL='true' \
        && unset INSTALL_MYSQL \
    ; fi \
    && if [ "$INSTALL_OPCACHE" != "false" ]; then \
        export INSTALL_OPCACHE='true' \
    ; fi \
    && if [ "$INSTALL_PGSQL" != "false" ]; then \
        export INSTALL_PGSQL='true' \
            INSTALL_PDO_PGSQL='true' \
            DEPS="$DEPS postgresql-client" \
    ; fi \
    && if [ "$INSTALL_SQLSRV" = "true" ]; then \
        export INSTALL_PDO_SQLSRV='true' \
    ; fi \
    && export INSTALL="$INSTALL $(env | grep '^INSTALL_.*=true$' | cut -d= -f1 | cut -d_ -f2- | tr '[:upper:]' '[:lower:]' | sort)" \
    && set -x \
    && if echo "$INSTALL" | fgrep -q sqlsrv; then \
        mkdir /tmp/sqlsrv \
        && cd /tmp/sqlsrv \
        && curl -Osf https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.5.1.1-1_amd64.apk \
        && curl -Osf https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/mssql-tools_17.5.1.2-1_amd64.apk \
        && apk add --no-cache --allow-untrusted \
            msodbcsql17_17.5.1.1-1_amd64.apk \
            mssql-tools_17.5.1.2-1_amd64.apk \
        && cd - \
        && rm -rf /tmp/sqlsrv \
    ; fi \
    && apk add $DEPS \
    && install-php-extensions $INSTALL
