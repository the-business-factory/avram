FROM crystallang/crystal:1.4.0-alpine
WORKDIR /data

# install base dependencies
RUN apk --no-cache add postgresql-client

# Lucky cli
RUN git clone https://github.com/luckyframework/lucky_cli --branch v0.27.0 --depth 1 /usr/local/lucky_cli && \
  cd /usr/local/lucky_cli && \
  shards install && \
  crystal build src/lucky.cr -o /usr/local/bin/lucky

COPY . /data