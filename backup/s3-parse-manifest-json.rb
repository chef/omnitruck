# Author: Tyler Cloke <tyler@opscode.com>
#
# Usage: ruby s3-parse-manifest-json.rb s3-filenames-file s3-access-key s3-secret-key s3-bucket-name s3-sub-bucket-name output-dir reversed-ruby (see reverse-release-json.rb for last arg help)
#
# Ruby script that parses .json manifest files from s3, downloads each file 
# endpoint in the json from s3 and stores them in the format required for 
# omnibus' RELEASE.rb script. See backup/README.md for details.
#
require "uber-s3"
require "JSON"
require "colorize"
require 'fileutils'

s3 = UberS3.new({
  :access_key         => ARGV[1],
  :secret_access_key  => ARGV[2],
  :bucket             => ARGV[3],
  :adapter            => :net_http
})

# file where each line is a ruby release version
file = File.open(ARGV[0]).read
# inverse of omnibus-chef/jenkins/release.rb file
reversed_json = JSON.parse(File.open(ARGV[6]).read)

# for each release manifest
file.each_line do |line|
  parts = line.split('/')
  # get the release manifest file name
  filename = "#{ARGV[4]}/#{parts[parts.length-1]}".strip

  file_found = false
  begin
    # get the json from the current release manifest
    json = JSON.parse(s3.get(filename).value)
    file_found = true
  rescue
    puts  "COULD NOT OPEN S3 FILE #{filename}".red
    `echo "COULD NOT OPEN S3 FILE #{filename}" >> backup-error-log`
  end

  puts "Downloading all files from #{filename}".green

  if file_found
    # for each platform => plat_version => architecture => chef_version
    json.each do |platform, platform_value|
      platform_value.each do |platform_version, platform_version_value| 
        platform_version_value.each do |arch, arch_value|
          arch_value.each do |chef_version, chef_version_value|
            # get the name of the omnibus version dir
            omnibus_dir = reversed_json[platform][platform_version][arch]
            # get the output path in omnibus format (see readme if interested in format)
            output_dir = "#{ARGV[5]}/#{chef_version}/#{omnibus_dir}/pkg/"

            # get the name of the chef build file
            file_name = chef_version_value.split("/")[-1]
            
            # make output path if it doesn't exist
            directory_exists = false
            begin
              if File.directory? output_dir
                directory_exists = true
                raise
              end
              FileUtils.mkdir_p(output_dir)
            rescue
              puts  "Directory already exists, not downloading #{file_name}".yellow
              `echo "Directory already exists, not downloading #{file_name}" >> backup-error-log`
              break
            end
            
            # rip that sucker down from s3 and into your output path, if you haven't dl-ed it yet
            if not directory_exists 
              begin
                `wget https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} -O #{output_dir}/#{file_name}`
              rescue
                puts  "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} to file #{file_name}".red
                `echo "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} to file #{file_name}" >> backup-error-log`
              end
            end
          end
        end
      end
    end        
  end
end
