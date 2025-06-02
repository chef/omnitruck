# Use a specific Ruby version that's compatible with your gems
FROM ruby:3.0-alpine

ENV APP_ROOT=/app
ENV RACK_ENV=production
ENV LANG=C.UTF-8

WORKDIR $APP_ROOT

# Install build dependencies for native extensions
RUN apk add --no-cache --update \
    build-base \
    linux-headers \
    git \
    tzdata \
    curl \
    openssl-dev \
    libc-dev

# Install bundler with specific version for consistency
RUN gem install bundler -v '2.3.26'

# Copy gemfiles first for better layer caching
COPY Gemfile Gemfile.lock $APP_ROOT/

# Install dependencies
RUN bundle config set without 'development test' && \
    bundle install

# Copy the rest of the application
COPY . $APP_ROOT

EXPOSE 8080 8000 443

CMD ["bundle", "exec", "unicorn"]