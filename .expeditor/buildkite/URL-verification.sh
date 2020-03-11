#!/bin/bash

set -eou pipefail

TARGET_ENVIRONMENT="${ENVIRONMENT:-acceptance}"

# This block tests the "environment" urls
if [ "$TARGET_ENVIRONMENT" == "acceptance" ]; then
  TARGET_DOMAIN="omnitruck-acceptance.chef.io"
elif [ "$TARGET_ENVIRONMENT" == "production" ]; then
  TARGET_DOMAIN="omnitruck.chef.io"
fi

curl --fail -I "https://$TARGET_DOMAIN/_status"
curl --fail -I "https://$TARGET_DOMAIN/install.sh"
curl --fail -I "https://$TARGET_DOMAIN/install.ps1"
curl --fail -I "https://$TARGET_DOMAIN/stable/chef/versions"
curl --fail -I "https://$TARGET_DOMAIN/stable/chef/metadata?p=ubuntu&pv=18.04&m=x86_64"
curl --fail -I "https://$TARGET_DOMAIN/stable/chef/download?p=ubuntu&pv=18.04&m=x86_64"
