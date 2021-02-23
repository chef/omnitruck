FROM ruby:alpine

LABEL maintainer="releng@chef.io"

RUN apk update && apk upgrade \
    && apk add --no-cache bash git openssh make cmake gcc libc-dev build-base

RUN set -x \
    # Run as non-root user
    && addgroup --system --gid 22430 releng \
    && adduser --system --disabled-password --ingroup releng --no-create-home \
        --gecos "releng user" --shell /bin/false \
        --uid 22430 releng

ENV APP_ROOT /usr/app

RUN mkdir -p $APP_ROOT

WORKDIR $APP_ROOT

COPY . $APP_ROOT

RUN bundle install

EXPOSE 8080 8000 443

ENV REDIS_URL "redis://host.docker.internal"

STOPSIGNAL SIGTERM

WORKDIR $APP_ROOT

USER releng

CMD bundle exec unicorn