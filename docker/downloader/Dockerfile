FROM ubuntu:22.04
FROM ruby:3.2.6

ARG rails_env=development
ENV RAILS_ENV=development
ENV RAILS_LOG_TO_STDOUT=true

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    nodejs \
    postgresql-client

EXPOSE 3000

# This is a host volume.
WORKDIR /app
RUN mkdir -p /home/downloader/storage

COPY storage/medusa/  /home/downloader/mnt/medusa-dev
COPY storage/idb/ /home/downloader/mnt/medusa-dev/156/182/
COPY storage/ideals/ /home/downloader/mnt/medusa-dev/186/243/

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/root/.gem \
    gem install bundler \
    && bundle install

COPY . ./

# Everything else has to be done in the entry command because /app will be
# empty until we launch via docker compose.
