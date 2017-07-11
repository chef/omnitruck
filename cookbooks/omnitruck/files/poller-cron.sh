#!/bin/bash

cd /hab/svc/omnitruck/static && $(hab pkg path core/bundler)/bin/bundle exec ./poller -e production > /dev/null 2>&1
