FROM ruby:latest

RUN mkdir -p /var/www/pokedex
WORKDIR /var/www/pokedex

COPY Gemfile /var/www/pokedex/
COPY Gemfile.lock /var/www/pokedex/

RUN bundle install

EXPOSE 3000
