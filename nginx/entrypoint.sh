#!/usr/bin/env bash

## start nginx in the background, kill both on exit
TRAPPED_SIGNAL=false

echo 'Starting NGINX';
nginx -g 'daemon off;' 2>&1 &
NGINX_PID=$!

trap "TRAPPED_SIGNAL=true; kill -15 $NGINX_PID;" SIGTERM  SIGINT

## watch nginx in an ongoing loop
while :
do
    kill -0 $NGINX_PID 2> /dev/null
    NGINX_STATUS=$?

    if [ "$TRAPPED_SIGNAL" = "false" ]; then
        if [ $NGINX_STATUS -ne 0 ]; then
            if [ $NGINX_STATUS -eq 0 ]; then
                kill -15 $NGINX_PID;
                wait $NGINX_PID;
            fi

            exit 1;
        fi
    else
       if [ $NGINX_STATUS -ne 0 ]; then
            exit 0;
       fi
    fi

    sleep 60
done