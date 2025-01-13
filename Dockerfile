FROM ruby:3.3 AS base

ARG UNAME=app
ARG UID=1000
ARG GID=1000

# COPY Gemfile* /usr/src/app/
WORKDIR /usr/src/app
#
ENV BUNDLE_PATH /gems
#
RUN gem install bundler
# Stop git from complaining about mismatched ownership
RUN git config --global --add safe.directory /usr/src/app
