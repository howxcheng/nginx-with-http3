#!/bin/env bash

CRON_FILE="/etc/crontab"
if [ ! -f $CRON_FILE ]; then
    echo "File $CRON_FILE does not exist."
    exit 0
fi

if [ "$(stat -c "%a" $CRON_FILE)" -ne "644" ]; then
    echo "Change $CRON_FILE permissions to 644"
    chmod 644 /etc/crontab
    crontab /etc/crontab
fi
