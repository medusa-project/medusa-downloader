ARG NGINX_MODZIP_PREFIX=/home/nginx
ARG NGINX_PLAIN_PREFIX=/home/nginx2

FROM ubuntu:22.04
FROM ruby:3.2.6 AS base

FROM base AS nginx_source
RUN  --mount=type=tmpfs,target=/tmp/archives \
     DOWNLOAD_URL='https://github.com/nginx/nginx/archive/refs/tags/release-1.29.8.tar.gz' && \
     EXPECTED_HASH='b40c6423ddceeeb3aef8673fd4611091819302329e3ba78df27930607d427994' && \
     curl -o /tmp/archives/nginx.tar.gz -L $DOWNLOAD_URL && \
     CALCULATED_HASH=$(sha256sum /tmp/archives/nginx.tar.gz | awk '{print $1}') && \
     if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then \
      echo "Hash does not match. Expected: $EXPECTED_HASH. Got: $CALCULATED_HASH."  && exit 1; \
     fi && \
     mkdir -p /src/nginx && \
      tar -zxvf /tmp/archives/nginx.tar.gz -C /src/nginx --strip-components=1

RUN git clone https://github.com/omonar/nginx-http-auth-digest.git /src/nginx-http-auth-digest


FROM base AS nginx_builder
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    git \
    zlib1g-dev \
    libpcre3-dev

FROM nginx_builder AS nginx_builder_plain

COPY --from=nginx_source /src/ /tmp/src
ARG NGINX_PLAIN_PREFIX
RUN cd /tmp/src/nginx && \
    ./auto/configure --prefix=$NGINX_PLAIN_PREFIX --with-compat --with-http_ssl_module --add-module=/tmp/src/nginx-http-auth-digest/ && \
    make && \
    make install

FROM nginx_builder AS nginx_builder_modzip
COPY --from=nginx_source /src/ /tmp/src

RUN  --mount=type=tmpfs,target=/tmp/archives \
     DOWNLOAD_URL='https://github.com/evanmiller/mod_zip/archive/refs/tags/1.3.0.tar.gz' && \
     EXPECTED_HASH='5e7f24b6b4efb8258d92ec921ade9df69e4bad36f833a39b47ee947b3d637f22' && \
     curl -o /tmp/archives/mod_zip.tar.gz -L $DOWNLOAD_URL && \
     CALCULATED_HASH=$(sha256sum /tmp/archives/mod_zip.tar.gz | awk '{print $1}') && \
     if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then \
      echo "Hash does not match. Expected: $EXPECTED_HASH. Got: $CALCULATED_HASH."  && exit 1; \
     fi && \
     mkdir -p /tmp/src/mod_zip && \
     tar -zxvf /tmp/archives/mod_zip.tar.gz -C /tmp/src/mod_zip --strip-components=1

ARG NGINX_MODZIP_PREFIX
RUN cd /tmp/src/nginx && \
    ./auto/configure --prefix=$NGINX_MODZIP_PREFIX --with-compat --add-dynamic-module=/tmp/src/mod_zip --with-http_ssl_module --add-module=/tmp/src/nginx-http-auth-digest/ && \
    make && \
    echo "installing to $NGINX_MODZIP_PREFIX" && \
    make install && \
    ls -la /tmp/src/nginx/objs/ngx_http_zip_module.so

FROM base

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    nodejs \
    postgresql-client \
    dirmngr gnupg apt-transport-https ca-certificates \
    jq &&\
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D870AB033FB45BD1 && \
    sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list' && \
    apt-get update && \
    apt-get install -y passenger && \
    /usr/bin/passenger-config validate-install

# This is a host volume.
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/root/.gem \
    gem install bundler && \
    bundle install

ARG NGINX_PLAIN_PREFIX
COPY --from=nginx_builder_plain --chmod=755 $NGINX_PLAIN_PREFIX/ $NGINX_PLAIN_PREFIX/
COPY docker/downloader/fileserve-nginx-config.cfg $NGINX_PLAIN_PREFIX/conf/nginx.conf
RUN ln -s $NGINX_PLAIN_PREFIX/sbin/nginx /usr/local/sbin/nginx && \
    mkdir -p /var/www/html && \
    ln -s $NGINX_PLAIN_PREFIX/html /var/www/html
ENV NGINX_PLAIN_PREFIX=$NGINX_PLAIN_PREFIX

ARG NGINX_MODZIP_PREFIX
COPY --from=nginx_builder_modzip --chmod=755 $NGINX_MODZIP_PREFIX/ $NGINX_MODZIP_PREFIX/
COPY docker/downloader/nginx-with-mod-zip.conf $NGINX_MODZIP_PREFIX/conf/nginx.conf
COPY docker/downloader/internal-nginx.conf $NGINX_MODZIP_PREFIX/conf/internal.conf
RUN ln -s $NGINX_MODZIP_PREFIX/sbin/nginx /usr/local/sbin/nginx-modzip && \
    touch $NGINX_MODZIP_PREFIX/conf/digest_users
ENV NGINX_MODZIP_PREFIX=$NGINX_MODZIP_PREFIX
COPY . ./

# To put this in to development, add "-e RAILS_ENV=development" to your docker run command
ENV RAILS_ENV=production \
    RAILS_HOME=/app \
    RAILS_LOG_TO_STDOUT=true

RUN mkdir -p /logs
COPY --chmod=755 docker/downloader/start.sh /usr/local/bin/start

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:80/downloads/status | jq -e '.mountpointMountStatus == "Success"' || exit 1

CMD ["start"]