#!/bin/bash

set -eou pipefail

TARGET_ENVIRONMENT="${ENVIRONMENT:-acceptance}"

# This block tests the "environment" urls
if [ "$TARGET_ENVIRONMENT" == "verify" ]; then
  TARGET_DOMAIN="http://localhost:8080"
elif [ "$TARGET_ENVIRONMENT" == "acceptance" ]; then
  TARGET_DOMAIN="https://omnitruck-acceptance.chef.io"
elif [ "$TARGET_ENVIRONMENT" == "production" ]; then
  TARGET_DOMAIN="https://omnitruck.chef.io"
fi

# Core Omnitruck endpoints
curl --fail -I "$TARGET_DOMAIN/_status"
curl --fail -I "$TARGET_DOMAIN/products"
curl --fail -I "$TARGET_DOMAIN/platforms"
curl --fail -I "$TARGET_DOMAIN/architectures"
curl --fail -I "$TARGET_DOMAIN/install.sh"
curl --fail -I "$TARGET_DOMAIN/install.ps1"
curl --fail -I "$TARGET_DOMAIN/stable/chef/metadata?p=ubuntu&pv=18.04&m=x86_64"
curl --fail -I "$TARGET_DOMAIN/stable/chef/download?p=ubuntu&pv=18.04&m=x86_64"

# Download Site endpoints
curl --fail -I "$TARGET_DOMAIN/stable/chef/versions"
curl --fail -I "$TARGET_DOMAIN/stable/chef/packages"
curl --fail -I "$TARGET_DOMAIN/stable/chef/versions/all"
curl --fail -I "$TARGET_DOMAIN/stable/chef/versions/latest"
