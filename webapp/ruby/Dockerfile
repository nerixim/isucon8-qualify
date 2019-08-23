FROM ruby:2.6-buster

RUN apt-get update && apt-get install mariadb-client

WORKDIR /app
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
RUN bundle install --system

ADD . /app
RUN bundle install --system
