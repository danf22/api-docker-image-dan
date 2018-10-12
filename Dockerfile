ARG PHP_VERSION=7.2
ARG ALPINE_VERSION=3.7
FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION}
ARG APCU_VERSION=5.1.11
ARG XDEBUG_VERSION=2.6.0
ARG SYMFONY_SKIP_REGISTRATION=1
ARG APP_ENV=staging
ARG BACKEND_CLONED_DIRECTORY=diocesan-api
ARG LINUX_USER=www-data

LABEL mantainer="efernandez@teravisiontech.com"

# Install&Conf packages process block
RUN apk --update add \
  curl \
  git \
  acl \
  sudo \
  shadow \
  openssl \
  nginx 

RUN set -xe \
  && apk add --no-cache --virtual .build-deps \
  $PHPIZE_DEPS \
  icu-dev \
  postgresql-dev \
  zlib-dev \		
  && docker-php-ext-install -j$(nproc) \
  intl \
  pdo_pgsql \
  zip \
  bcmath \
  && pecl install \
  apcu-${APCU_VERSION} \
  xdebug-${XDEBUG_VERSION} \
  && pecl clear-cache \
  && docker-php-ext-enable --ini-name 20-apcu.ini apcu \
  && docker-php-ext-enable --ini-name 05-opcache.ini opcache \
  && docker-php-ext-enable xdebug \
  && docker-php-ext-enable bcmath \
  && runDeps="$( \
  scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
  | tr ',' '\n' \
  | sort -u \
  | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && apk add --no-cache --virtual .api-phpexts-rundeps $runDeps \
  && apk del .build-deps	
# END install&conf packages process block

# Composer Block #
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY ./php/php.ini /usr/local/etc/php/php.ini

ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer self-update
ENV PATH="${PATH}:/root/.composer/vendor/bin"
# Composer plugin for parallel installs ;) it is much faster!	
RUN composer global require hirak/prestissimo
# END Composer Block #

RUN rm -rf /var/cache/apk/*

# Nginx Block
RUN mkdir /autostart
COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
#End block

#Project directory - step 26/38
WORKDIR /srv/api
COPY ./${BACKEND_CLONED_DIRECTORY} ./

VOLUME /srv/api

RUN mkdir -p var/cache var/log var/sessions \
  && chmod +x bin/console && sync
#End Block

# Generate public and private keys for JWT-AUTHENTICATION-BUNDLE
COPY .php/jwt.sh /tmp/
RUN chmod u+x /tmp/jwt.sh
RUN sh /tmp/jwt.sh
# End block

COPY ./php/symfony-entrypoint.sh /usr/local/bin/symfony-entrypoint
RUN chmod +x /usr/local/bin/symfony-entrypoint

RUN usermod -u 1000 ${LINUX_USER} \
  && groupmod -g 1000 ${LINUX_USER} \
  && sed -i 's/www-data:\/bin\/false/www-data:\/bin\/sh/' /etc/passwd

RUN ln -s /usr/local/bin/php /usr/bin/php \
  && chown ${LINUX_USER}:${LINUX_USER} /usr/local/bin/php \ 
  && chmod 755 /usr/local/

ENTRYPOINT [ "symfony-entrypoint" ]
CMD ["php-fpm"]
