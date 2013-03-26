#!/usr/bin/env ruby

RELEASE_RB_PATH = "/mnt/work/omnibus-chef/jenkins/release.rb"
PACKAGES_BUCKET = "opscode-omnibus-packages"
METADATA_BUCKET = "opscode-omnibus-package-metadata"
PROJECT = "chef-server"

# -p chef -v $CHEF_VERSION-$CHEF_PACKAGE_ITERATION -b opscode-omnitruck-test -m ~/.s3-metadata-upload-cfg -M opscode-omnibus-package-metadata-test

# Sanity checks:
unless File.directory?("s3-client-backup")
  $stderr.puts "you need to run this script from the omnitruck/backup directory"
  $stderr.puts "and have already fetched the client packages"
  exit 1
end

METADATA_S3CMD_CONFIG = File.expand_path("~/.s3-metadata-upload-cfg")
unless File.readable?(METADATA_S3CMD_CONFIG)
  $stderr.puts "You need to configure s3cmd for the metadata account"
  $stderr.puts "config goes in #{METADATA_S3CMD_CONFIG}"
  exit 1
end

PACKAGES_S3CMD_CONFIG = File.expand_path("~/.s3-package-upload-cfg")

unless File.readable?(PACKAGES_S3CMD_CONFIG)
  $stderr.puts "You need to configure s3cmd for the package upload account"
  $stderr.puts "config goes in #{PACKAGES_S3CMD_CONFIG}"
  exit 1
end

Dir["s3-server-backup/*"].each do |release_dir|
  Dir.chdir(release_dir) do
    release_version = File.basename(release_dir)
    puts "** RELEASING #{release_version} **"
    release_cmd = [
      RELEASE_RB_PATH,
      "-c #{PACKAGES_S3CMD_CONFIG}",
      "-p #{PROJECT}",
      "-v #{release_version}",
      "-b #{PACKAGES_BUCKET}",
      "-m #{METADATA_S3CMD_CONFIG}",
      "-M #{METADATA_BUCKET}",
      "--ignore-missing-packages"
    ].join(" ")
    puts release_cmd
    raise "release failed!" unless system(release_cmd)
  end
end
