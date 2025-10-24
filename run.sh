#!/bin/sh

DB_PATH="/app/data/kuma.db"

echo "1. Ensuring the data directory is writable and the database file exists..."
mkdir -p /app/data

# 强制创建文件，确保权限
if [ ! -f "$DB_PATH" ]; then
    touch "$DB_PATH"
    echo "    -> Created empty database file at $DB_PATH."
fi
chmod 660 "$DB_PATH"

echo "2. Trying to restore data from Backblaze B2."
# 🚨 修复: 移除 Litestream v0.5.1 不支持的标志
# 尝试恢复。使用 -if-db-not-exists，如果数据库不存在，litestream restore 会恢复。
/usr/local/bin/litestream restore -if-db-not-exists "$DB_PATH"
RESTORE_STATUS=$?

echo "3. Checking database size for initialization..."
# 检查数据库文件是否为空 (文件大小 > 0)
if [ ! -s "$DB_PATH" ]; then
    echo "    -> Database is empty. Running Uptime Kuma once to force initialization."
    
    # 启动 Uptime Kuma 进程，让它在后台运行
    node /app/server/server.js &
    KUMA_PID=$!
    
    # 增加等待时间，确保初始化完成
    KUMA_INIT_TIMEOUT=15
    echo "    -> Waiting ${KUMA_INIT_TIMEOUT} seconds for Uptime Kuma to initialize tables..."
    sleep $KUMA_INIT_TIMEOUT
    
    # 终止初始化进程
    if kill -0 $KUMA_PID 2>/dev/null; then
        echo "    -> Killing initialization process (PID $KUMA_PID)."
        kill $KUMA_PID
        wait $KUMA_PID 2>/dev/null
    else
        echo "    -> Initialization process already terminated."
    fi
else
    echo "    -> Database is NOT empty. Skipping forced initialization."
fi

echo "4. Starting Litestream replication and the application..."
# 启动 Litestream 和 Uptime Kuma
exec /usr/local/bin/litestream replicate -config /etc/litestream.yml
