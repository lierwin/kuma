#!/bin/sh

DB_PATH="/app/data/kuma.db"

echo "1. Ensuring the data directory is writable and the database file exists..."

# 确保 /app/data 目录存在且可写
mkdir -p /app/data

# 强制创建一个空的数据库文件，并确保当前运行用户有权限
# 这一步至关重要，它确保了文件在 Uptime Kuma 启动前就存在
if [ ! -f "$DB_PATH" ]; then
    touch "$DB_PATH"
    echo "    -> Created empty database file at $DB_PATH."
fi
chmod 660 "$DB_PATH" # 确保文件权限允许读写

echo "2. Trying to restore data from Backblaze B2..."
# Litestream restore 会尝试下载快照，如果成功，它会覆盖上面的空文件。
# 如果失败（例如没有快照），它会静默跳过，但空文件已存在。
# 使用 -if-exists 来避免在没有远程副本时发出警告
/usr/local/bin/litestream restore -v -if-exists "$DB_PATH"

echo "3. Starting Litestream replication and Uptime Kuma..."
# 使用 exec 确保 Litestream 成为 PID 1
# Litestream 发现 kuma.db 存在，就会开始监控和复制
exec /usr/local/bin/litestream replicate -config /etc/litestream.yml
