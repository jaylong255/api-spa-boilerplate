#!/usr/bin/env bash

## start php in the background, kill on exit
TRAPPED_SIGNAL=false

echo 'Starting PHP-FPM';
php-fpm 2>&1 &
PHP_FPM_PID=$!

trap "TRAPPED_SIGNAL=true; kill -15 $PHP_FPM_PID;" SIGTERM  SIGINT

## watch php in an ongoing loop
while :
do
    kill -0 $PHP_FPM_PID 2> /dev/null
    PHP_FPM_STATUS=$?

    if [ "$TRAPPED_SIGNAL" = "false" ]; then
        if [ $PHP_FPM_STATUS -ne 0 ]; then
            if [ $PHP_FPM_STATUS -eq 0 ]; then
                kill -15 $PHP_FPM_PID;
                wait $PHP_FPM_PID;
            fi

            exit 1;
        fi
    else
       if [ $PHP_FPM_STATUS -ne 0 ]; then
            exit 0;
       fi
    fi

    sleep 60
done