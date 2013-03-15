# Author: Tyler Cloke <tyler@opscode.com>
# Usage cd ~/oc/opscode-omnitruck && ./backup-s3-bucket.sh
#
# Shell script that grabs all the s3 opscode-omnitruck-release/chef-*-platform-support buckets
# and downloads every build we have. It backs them up to s3-client-backup/ and s3-server-backup/
#
# See backup/README.md for details.
#
#!/bin/bash

# grab the s3 key from s3cfg
SECRET_KEY=`grep secret_key config/s3cfg | cut -d ' ' -f 3`
ACCESS_KEY=`grep access_key config/s3cfg | cut -d ' ' -f 3`

# make backup dirs and files
mkdir s3-client-backup
mkdir s3-client-backup
mkdir s3-server-backup
touch backup-error-log

# grab all the .json files from opscode-omnitruck-release 
# and each file name on a line in client_migrate_manifest_names
s3cmd ls -c config/s3cfg s3://opscode-omnitruck-release/chef-platform-support/ | tr -s ' ' | cut -d ' ' -f 4 | grep .json | grep -v *chef-platform* > client_migrate_manifest_names

# parse client_migrate_manifest_names, and backup all the builds to s3-client-backup
ruby s3-parse-manifest-json.rb "client_migrate_manifest_names" $ACCESS_KEY $SECRET_KEY "opscode-omnitruck-release" "chef-platform-support" "s3-client-backup" "chef-reversed.json"

# do a similar thing for server
s3cmd ls -c config/s3cfg s3://opscode-omnitruck-release/chef-server-platform-support/ | tr -s ' ' | cut -d ' ' -f 4 | grep .json | grep -v *chef-platform* > server_migrate_manifest_names

ruby s3-parse-manifest-json.rb "server_migrate_manifest_names" $ACCESS_KEY $SECRET_KEY "opscode-omnitruck-release" "chef-platform-support" "s3-server-backup" "chef-server-reversed.json"
