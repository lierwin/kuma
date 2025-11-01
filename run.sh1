#!/bin/sh

DB_PATH="/app/data/kuma.db"

echo "1. Ensuring the data directory is writable and the database file exists..."
mkdir -p /app/data

# 强制创建一个空文件，确保权限
if [ ! -f "$DB_PATH" ]; then
    touch "$DB_PATH"
    echo "    -> Created empty database file at $DB_PATH."
fi
chmod 660 "$DB_PATH"

echo "2. Trying to restore data from Backblaze B2."
# 使用 -if-db-not-exists：如果数据库文件不存在，尝试恢复。
# 如果远程备份不存在，此命令可能会返回非零退出码，但我们忽略它。
# 🚨 关键：我们移除之前手动创建空文件的逻辑，让 Litestream 恢复失败后返回的非零状态码通过。
# 这一步将**只在远程有快照时**生效。
/usr/local/bin/litestream restore -if-db-not-exists "$DB_PATH" || true 
# '|| true' 确保即使 Litestream 恢复失败，脚本也不会退出。

echo "3. Starting Litestream replication and the application..."
# Litestream 启动复制，并执行 Uptime Kuma。
# 如果 kuma.db 是新的空文件：
# 1. Litestream 开始监控。
# 2. Uptime Kuma 启动，发现数据库为空，开始初始化，创建表结构。
# 3. Litestream 开始复制新创建的 WAL 文件。
exec /usr/local/bin/litestream replicate -config /etc/litestream.yml
