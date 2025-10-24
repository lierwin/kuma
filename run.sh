#!/bin/sh

DB_PATH="/app/data/kuma.db"

echo "1. Ensuring the data directory is writable and the database file exists..."
mkdir -p /app/data
# 确保文件存在
if [ ! -f "$DB_PATH" ]; then
    touch "$DB_PATH"
    echo "    -> Created empty database file at $DB_PATH."
fi
chmod 660 "$DB_PATH" 

echo "2. Trying to restore data from Backblaze B2 (Removed -v flag)..."
# 移除 -v 标志
/usr/local/bin/litestream restore -if-exists "$DB_PATH"

# ----------------------------------------------------------------------
# 🚨 关键修复：强制 Uptime Kuma 初始化数据库结构
# ----------------------------------------------------------------------
if [ ! -s "$DB_PATH" ]; then
    echo "3A. Database is empty. Running Uptime Kuma once to force initialization..."
    # 启动 Uptime Kuma 进程，但让它在后台运行 (使用 &)
    node /app/server/server.js &
    # 获取进程ID
    KUMA_PID=$!
    
    # 等待 10 秒，让 Uptime Kuma 有足够时间创建必要的表结构
    echo "    -> Waiting 10 seconds for Uptime Kuma to initialize tables..."
    sleep 10
    
    # 杀死初始化进程
    echo "    -> Killing initialization process (PID $KUMA_PID)."
    kill $KUMA_PID
    
    # 确保进程已完全终止
    wait $KUMA_PID 2>/dev/null
else
    echo "3A. Database is NOT empty. Skipping forced initialization."
fi
# ----------------------------------------------------------------------

echo "3B. Starting Litestream replication and Uptime Kuma..."
# Litestream 启动复制，并执行 Uptime Kuma。
# 此时 kuma.db 文件已包含基础表结构，不会触发 SQLITE_ERROR
exec /usr/local/bin/litestream replicate -config /etc/litestream.yml
