#!/bin/bash

while true; do
    php -f /var/www/nextcloud/cron.php &
    sleep 5m
done
