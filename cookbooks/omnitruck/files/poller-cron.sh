#!/bin/bash

PATH=$(hab pkg path core/bundler)/bin:$(hab pkg path core/ruby)/bin:$(hab pkg path core/coreutils)/bin:/usr/local/bin:/usr/local/sbin/:/usr/bin:/usr/sbin/:/bin:/sbin
RUBY_VERSION="$(hab pkg path core/ruby | rev | cut -d '/' -f 2 | rev | cut -d '.' -f 1-2).0"
GEM_HOME="$(hab pkg path chef-es/omnitruck)/static/vendor/bundle/ruby/$RUBY_VERSION"
GEM_PATH="$(hab pkg path core/ruby)/lib/ruby/gems/$RUBY_VERSION:$(hab pkg path core/bundler):$GEM_HOME"
LD_LIBRARY_PATH="$(hab pkg path core/gcc-libs)/lib"
SSL_CERT_FILE="$(hab pkg path core/cacerts)/ssl/cert.pem"

export PATH GEM_HOME GEM_PATH LD_LIBRARY_PATH SSL_CERT_FILE


cd /hab/svc/omnitruck/static && $(hab pkg path core/bundler)/bin/bundle exec ./poller -e production > /dev/null 2>&1
