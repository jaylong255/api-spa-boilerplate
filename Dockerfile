# Set host user and group id for all stages
ARG HOST_USER_UID=1001
ARG HOST_USER_GID=1001

# Vue.js SPA to Consume the API
FROM node:lts-alpine as spa

RUN npm install -g @vue/cli

ARG HOST_USER_UID
ARG HOST_USER_GID

WORKDIR /app
COPY . .

# Add the user that will be expected
RUN addgroup --gid ${HOST_USER_GID} app
RUN adduser --system --no-create-home --uid $HOST_USER_UID --ingroup app webuser

RUN chown -R webuser:app /app

EXPOSE 8080

CMD [ "yarn", "serve" ]

FROM php:7.4-cli as worker

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
RUN addgroup --gid ${HOST_USER_GID} app
RUN adduser --system --no-create-home --uid $HOST_USER_UID --ingroup app webuser

WORKDIR /app

