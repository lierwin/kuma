#!/bin/sh

DB_PATH="/app/data/kuma.db"
KUMA_INIT_TIMEOUT=15  # 增加初始化等待时间到 15 秒

echo "1. Ensuring the data directory is writable and the database file exists..."
mkdir -p /app/data

# 检查数据库文件是否已经存在
if [ ! -f "$DB_PATH" ]; then
    touch "$DB_PATH"
    echo "    -> Created empty database file at $DB_PATH."
fi
chmod 660 "$DB_PATH"

echo "2. Trying to restore data from Backblaze B2 (Using standard restore command)..."
# 🚨 修复: 移除所有不支持的标志，使用标准命令。
# 如果远程有备份，它会恢复；如果没有，它会提示找不到备份并退出，但 DB 文件已存在。
# 注意：v0.5.1版本的restore命令在没有找到备份时会返回非零退出码，但这不是致命错误。
/usr/local/bin/litestream restore "$DB_PATH"

# ----------------------------------------------------------------------
# 🚨 关键修复：强制 Uptime Kuma 初始化数据库结构
# 使用 -s 检查文件是否为空（SQLite 初始化后文件大小会 > 0）
# ----------------------------------------------------------------------
if [ ! -s "$DB_PATH" ]; then
    echo "3A. Database is empty. Running Uptime Kuma once to force initialization."
    
    # 启动 Uptime Kuma 进程，让它在后台运行
    node /app/server/server.js &
    KUMA_PID=$!
    
    echo "    -> Waiting $KUMA_INIT_TIMEOUT seconds for Uptime Kuma to initialize tables..."
    # 睡眠等待初始化完成
    sleep $KUMA_INIT_TIMEOUT
    
    # 检查进程是否还在运行，并终止
    if kill -0 $KUMA_PID 2>/dev/null; then
        echo "    -> Killing initialization process (PID $KUMA_PID)."
        kill $KUMA_PID
        wait $KUMA_PID 2>/dev/null
    else
        echo "    -> Initialization process already terminated."
    fi
else
    echo "3A. Database is NOT empty. Skipping forced initialization."
fi
# ----------------------------------------------------------------------

echo "3B. Starting Litestream replication and Uptime Kuma..."
# 此时 kuma.db 要么是恢复的，要么是经过 Uptime Kuma 初始化后的。
exec /usr/local/bin/litestream replicate -config /etc/litestream.yml
