#!/bin/bash

set -eou pipefail

sudo apt-get update
sudo apt-get install -y redis
echo "Starting Redis Server"
redis-server &
echo "Bundle Install"
bundle install --path vendor/bundle
echo "Running omnitruck poller"
bundle exec ./poller
echo "Running omnitruck web-proxy"
bundle exec unicorn &
echo "Waiting for web-proxy to start"
sleep 10
echo "Verify processes running"
ps -ef |grep unicorn
echo "Testing omnitruck web-proxy"
curl --fail -I http://0.0.0.0:8080/_status
curl --fail -I http://0.0.0.0:8080/stable/chef/versions
