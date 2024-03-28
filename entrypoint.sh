#!/bin/sh -eux
if [ ! -f "/apps/run.sh" ]; then
cat << EOF > /apps/run.sh
#!/bin/ash
echo "Run success"
exit 0
EOF
fi
chmod +x /apps/run.sh
/bin/ash /apps/run.sh
exec "$@"
# else
#     mkdir -p /media/.tmp
#     exec "$@"
# fi
