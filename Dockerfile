# frozen_string_literal: true

FROM ruby:3.3.6-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  libpq-dev \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/pokedex
WORKDIR /var/www/pokedex

COPY Gemfile /var/www/pokedex/
COPY Gemfile.lock /var/www/pokedex/

RUN bundle install

EXPOSE 3000

CMD ["bundle", "exec", "ruby", "server.rb"]
