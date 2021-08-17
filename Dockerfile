FROM ruby:alpine

LABEL maintainer="releng@chef.io"

ENV APP_ROOT="/usr/app" \
    REDIS_URL="redis://host.docker.internal"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache bash git openssh make cmake gcc libc-dev build-base

# create the `releng` user
RUN set -x && \
    addgroup --system --gid 22430 releng && \
    adduser --system --disabled-password --ingroup releng \
        --gecos "releng user" --shell /bin/false \
        --uid 22430 releng

# copy over omnitruck app contents
RUN mkdir -p $APP_ROOT

COPY . $APP_ROOT

WORKDIR $APP_ROOT

RUN bundle install

USER releng

EXPOSE 8080

CMD ["bundle", "exec", "unicorn"]