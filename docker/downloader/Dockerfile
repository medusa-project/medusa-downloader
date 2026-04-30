FROM ubuntu:22.04
FROM ruby:3.2.6 AS base

FROM base AS builder
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    git \
    zlib1g-dev \
    libpcre3-dev
RUN  --mount=type=tmpfs,target=/tmp/archives \
     DOWNLOAD_URL='https://github.com/evanmiller/mod_zip/archive/refs/tags/1.3.0.tar.gz' && \
     EXPECTED_HASH='5e7f24b6b4efb8258d92ec921ade9df69e4bad36f833a39b47ee947b3d637f22' && \
     curl -o /tmp/archives/mod_zip.tar.gz -L $DOWNLOAD_URL && \
     CALCULATED_HASH=$(sha256sum /tmp/archives/mod_zip.tar.gz | awk '{print $1}') && \
     if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then \
      echo "Hash does not match. Expected: $EXPECTED_HASH. Got: $CALCULATED_HASH."  && exit 1; \
     fi && \
     mkdir -p /tmp/mod_zip && \
     tar -zxvf /tmp/archives/mod_zip.tar.gz -C /tmp/mod_zip --strip-components=1
RUN  --mount=type=tmpfs,target=/tmp/archives \
     DOWNLOAD_URL='https://github.com/nginx/nginx/archive/refs/tags/release-1.29.8.tar.gz' && \
     EXPECTED_HASH='b40c6423ddceeeb3aef8673fd4611091819302329e3ba78df27930607d427994' && \
     curl -o /tmp/archives/nginx.tar.gz -L $DOWNLOAD_URL && \
     CALCULATED_HASH=$(sha256sum /tmp/archives/nginx.tar.gz | awk '{print $1}') && \
     if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then \
      echo "Hash does not match. Expected: $EXPECTED_HASH. Got: $CALCULATED_HASH."  && exit 1; \
     fi && \
     mkdir -p /tmp/nginx && \
      tar -zxvf /tmp/archives/nginx.tar.gz -C /tmp/nginx --strip-components=1

RUN cd /tmp/nginx && \
    ./auto/configure --with-compat --add-dynamic-module=/tmp/mod_zip && \
    make && \
    make install && \
    ls -la /tmp/nginx/objs/ngx_http_zip_module.so

FROM base
ARG rails_env=development
ENV RAILS_ENV=development
ENV RAILS_LOG_TO_STDOUT=true

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    nodejs \
    postgresql-client \
    jq

# This is a host volume.
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/root/.gem \
    gem install bundler \
    && bundle install

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends nginx
COPY docker/downloader/fileserve-nginx-config.cfg /etc/nginx/nginx.conf

COPY --from=builder --chmod=755 /usr/local/nginx /usr/local/nginx
COPY docker/downloader/nginx-with-mod-zip.conf /usr/local/nginx/conf/nginx.conf
COPY . ./

# To put this in to development, add "-e RAILS_ENV=development" to your docker run command
ENV RAILS_ENV="production"

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:80/downloads/status | jq -e '.mountpointMountStatus == "Success"' || exit 1

RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log && \
    ln -sf /dev/stderr /usr/local/nginx/logs/error.log
COPY --chmod=755 docker/downloader/start.sh /usr/local/bin/start
CMD ["start"]