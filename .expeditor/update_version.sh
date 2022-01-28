#!/bin/sh

set -evx

version=$(cat VERSION)

# Update version for dobi
sed -i -r "s/^(\\s*)VERSION: \".+\"/\\1VERSION: \"$version\"/" .expeditor/build.docker.yml
sed -i -r "s/^version: .+/version: $version/" charts/omnitruck/Chart.yaml
sed -i -r "s/^(.*):version => \".+\")/\\1:version => \"$version\"\)/" app.rb
