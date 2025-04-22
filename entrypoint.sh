#!/bin/bash

crontab /etc/crontab
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf