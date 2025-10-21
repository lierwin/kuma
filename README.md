我的dockerfile
# ========== Builder image ==========
FROM docker.io/alpine AS BUILDER

RUN apk add --no-cache curl jq tar

# 下载并安装 litestream v0.5.1 (Linux x86_64)
RUN curl -L https://github.com/benbjohnson/litestream/releases/download/v0.5.1/litestream-0.5.1-linux-x86_64.tar.gz -o /tmp/litestream.tar.gz \
    && tar -xzf /tmp/litestream.tar.gz -C /usr/local/bin \
    && rm /tmp/litestream.tar.gz

# ========== Main image ==========
FROM docker.io/louislam/uptime-kuma AS KUMA

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

# 从构建阶段复制 litestream 可执行文件
COPY --from=BUILDER /usr/local/bin/litestream /usr/local/bin/litestream

# 复制配置与启动脚本
COPY litestream.yml /etc/litestream.yml
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

EXPOSE ${UPTIME_KUMA_PORT}

CMD ["/usr/local/bin/run.sh"]

我的litestream.yml
# Automatically start Uptime Kuma when Litestream begins replicating
exec: node /app/server/server.js
dbs:
  - path: /app/data/kuma.db
    replicas:
      - type: s3
        access-key-id: '${LITESTREAM_ACCESS_KEY_ID}'
        secret-access-key: '${LITESTREAM_SECRET_ACCESS_KEY}'
        bucket: '${LITESTREAM_BUCKET}'
        path: '${LITESTREAM_PATH}'
        endpoint: '${LITESTREAM_URL}'
        region: '${LITESTREAM_REGION}'
        retention: 72h
        snapshot-interval: 12h

我的run.sh
#!/bin/sh

echo "trying to restore the database (if it exists)..."
litestream restore -v -if-replica-exists /app/data/kuma.db

echo "starting replication and the application..."
litestream replicate
