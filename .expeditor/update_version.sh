#!/bin/sh

set -evx

version=$(cat VERSION)

# Update version for dobi
sed -i -r "s/^(\\s*)VERSION: \".+\"/\\1VERSION: \"$version\"/" .expeditor/build.docker.yml
sed -i.bak -r "s/^version: .+/version: $version/" charts/expeditor/Chart.yaml