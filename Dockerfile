# Set host user and group id for all stages
ARG HOST_USER_UID=1001
ARG HOST_USER_GID=1001

################################################
# Stage 1 [Composer] - Install PHP Dependencies
################################################

# Build php depenedencies from a composer stage so we can 
# drop all the composer stuff from the final container build

FROM composer as vendor

WORKDIR /app

COPY ./api/composer.json ./api/composer.lock /app/

RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --quiet

# Vue.js SPA to Consume the API
FROM node:lts-alpine as spadev

ARG HOST_USER_UID
ARG HOST_USER_GID

# Add the user that will be expected
RUN addgroup --gid ${HOST_USER_GID} nginx
RUN adduser --system --no-create-home --uid $HOST_USER_UID --ingroup nginx webuser

WORKDIR /app
COPY --chown=webuser:nginx ./spa/. /app/

RUN npm install -g @vue/cli

# EXPOSE 8080

# CMD [ "yarn", "serve" ]

FROM php:7.4-cli as apidev

ARG HOST_USER_UID
ARG HOST_USER_GID

RUN apt-get -y update && apt-get -y upgrade

RUN apt-get install -y wget \
    curl \
    git \
    grep \
    # build-base \
    libmemcached-dev \
    libmcrypt-dev \
    libxml2-dev \
    # imagemagick-dev \
    # pcre-dev \
    libtool \
    make \
    autoconf \
    g++ \
    # cyrus-sasl-dev \
    libgsasl-dev \
    zip \
    unzip \
    zlib1g-dev \
    libzip-dev \
    supervisor \
    mariadb-client

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN docker-php-ext-configure pcntl --enable-pcntl
RUN docker-php-ext-install pcntl

# RUN docker-php-ext-configure zip --with-libzip
RUN docker-php-ext-configure zip
RUN docker-php-ext-install zip
RUN docker-php-ext-enable zip

RUN apt-get update \
  && docker-php-ext-install pdo_mysql mysqli

RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli

# Add the user that will be expected
RUN addgroup --gid ${HOST_USER_GID} nginx
RUN adduser --system --no-create-home --uid $HOST_USER_UID --ingroup nginx webuser

WORKDIR /app

COPY --chown=webuser:nginx ./api/. /app/
COPY --from=vendor --chown=webuser:nginx /app/vendor/. /app/vendor

# EXPOSE 8000

# CMD [ "php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]


#############################################
# Stage 3 [PHP Fpm] - Serve the App Upstream
#############################################

# - Install all of the server software that PHP requires.
# - Add the web user and group.
# - Copy all of the PHP scripts from Stage 2.
# - Fix the permissions.
# - Serve PHP scripts upstream to nginx with Fpm. 

FROM php:7.4-fpm-alpine as app

ARG HOST_USER_UID
ARG HOST_USER_GID

# Install apt packages
RUN apk upgrade --update && apk add git\
  libmcrypt-dev \
  zip \
  libzip-dev \
  unzip

RUN apk add --update --no-cache --virtual .build-dependencies $PHPIZE_DEPS \
        && pecl install apcu \
        && docker-php-ext-enable apcu \
        && pecl clear-cache \
        && apk del .build-dependencies

RUN docker-php-ext-install mysqli pdo_mysql

# Copy over the config files that we packaged in
COPY ./php/php.ini /usr/local/etc/php/
COPY ./php/php-fpm.conf /usr/local/etc/
COPY ./php/entrypoint.sh /usr/local/bin/

# Add the user that nginx will be expecting
RUN addgroup --gid $HOST_USER_GID nginx
RUN adduser --system --no-create-home -D --uid $HOST_USER_UID --ingroup nginx webuser

WORKDIR /var/www/html

# Get latest Composer
# COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
# or
# RUN curl -s https://getcomposer.org/installer | php
# RUN alias composer='php composer.phar'

# Copy the site files 
# COPY --from=backend --chown=ec2-user:nginx /app/. /var/www/html
# RUN mkdir /var/www/html/vendor

COPY --chown=webuser:nginx --from=apidev /app/. /var/www/html
# COPY --chown=webuser:nginx --from=vendor /app/vendor/. /var/www/html/vendor

RUN chown webuser:nginx -R /var/www/html

RUN docker-php-ext-configure zip
RUN docker-php-ext-install zip
RUN docker-php-ext-enable zip

# Run the commands for the app container
CMD ["/usr/local/bin/docker-php-entrypoint","php-fpm","-F"]


###############################
# Stage 5 [Nginx] - Web Server
###############################

# - Copy all of the static files from Stages 2 and 4.
# - Create the same user that exists in Stage 3.
# - Copy the config files and fix the file permissions.
# - Serve the website with Nginx.

FROM nginx:alpine as web

ARG HOST_USER_UID
ARG HOST_USER_GID

ARG UPSTREAM

RUN apk add --upgrade brotli-libs

# Copy nginx config from files we packaged in
COPY ./nginx/nginx.conf /etc/nginx/
COPY ./nginx/default.conf /etc/nginx/conf.d
COPY ./nginx/${UPSTREAM}.conf /etc/nginx/conf.d

# Add the user that php expects to the nginx group
RUN adduser --system --no-create-home -D --uid $HOST_USER_UID --ingroup nginx webuser

# # Create the site directory
# RUN mkdir -p /var/www/html/assets
# RUN mkdir -p /var/www/html/public/build

# Copy just the files that we need and leave the surreal stage behind for the push
WORKDIR /var/www/html/public

# RUN echo "this is not the php script you're looking for." > index.html

# COPY --from=backend --chown=ec2-user:nginx /app/public/. /var/www/html/public
# COPY --from=frontend --chown=ec2-user:nginx /app/public/build/. /var/www/html/public/build

COPY --from=apidev --chown=webuser:nginx /app/public/. /var/www/html/public