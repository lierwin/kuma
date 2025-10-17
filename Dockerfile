# Builder image
FROM docker.io/alpine as BUILDER

RUN apk add --no-cache curl jq tar

RUN curl -L https://github.com/benbjohnson/litestream/releases/download/v0.5.2/litestream-0.5.2-linux-arm64.tar.gz -o /tmp/litestream.tar.gz \
    && tar -xzf /tmp/litestream.tar.gz -C /usr/local/bin \
    && rm /tmp/litestream.tar.gz

# Main image
FROM docker.io/louislam/uptime-kuma as KUMA

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

COPY --from=BUILDER /litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml
COPY run.sh /usr/local/bin/run.sh

EXPOSE ${UPTIME_KUMA_PORT}

CMD [ "/usr/local/bin/run.sh" ]
