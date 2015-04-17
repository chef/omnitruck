# Author: Tyler Cloke <tyler@opscode.com>
# Usage cd ~/oc/opscode-omnitruck && ./backup-s3-bucket.sh
#
# Shell script that grabs all the s3 opscode-omnitruck-release/chef-*-platform-support buckets
# and downloads every build we have. It backs them up to s3-client-backup/.
#
# See backup/README.md for details.
#
#!/bin/bash

# make backup dirs and files
mkdir s3-client-backup
touch backup-error-log

# grab all the .json files from opscode-omnitruck-release
# and each file name on a line in client_migrate_manifest_names
s3cmd ls -c ../config/s3cfg s3://opscode-omnitruck-release/chef-platform-support/ | tr -s ' ' | cut -d ' ' -f 4 | grep .json | grep -v chef-platform-names.json > client_migrate_manifest_names

# parse client_migrate_manifest_names, and backup all the builds to s3-client-backup
ruby s3-parse-manifest-json.rb "client_migrate_manifest_names" "opscode-omnitruck-release" "chef-platform-support" "s3-client-backup" "chef-reversed.json"
