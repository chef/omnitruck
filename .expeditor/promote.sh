#!/bin/bash

set -eou pipefail

APP=omnitruck

# PROMOTABLE - reference to the source channel used in the `/expeditor promote THING PROMOTABLE`
# TARGET_CHANNEL - the channel which we are promoting to
# HAB_AUTH_TOKEN - Authentication access token for the chef-ci account

source_channel="${PROMOTABLE:?You must provide a PROMOTABLE}"
target_channel="${TARGET_CHANNEL:?You must provide a TARGET_CHANNEL}"

# We pipe this to jq here so we can get only the ident we care about, as there may be invalid characters
# in the full results that cause jq to exit with this:
#
# parse error: Invalid string: control characters from U+0000 through U+001F must be escaped at line 15, column 12
#
results=$(curl --silent -H "Authorization: Bearer $HAB_AUTH_TOKEN" https://willem.habitat.sh/v1/depot/channels/chefops/$source_channel/pkgs/$APP/latest | jq '.ident')

pkg_origin=$(echo "$results" | jq -r .origin)
pkg_name=$(echo "$results" | jq -r .name)
pkg_version=$(echo "$results" | jq -r .version)
pkg_release=$(echo "$results" | jq -r .release)

hab pkg promote "${pkg_origin}/${pkg_name}/${pkg_version}/${pkg_release}" "${target_channel}"
