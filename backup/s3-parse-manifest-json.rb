# Author: Tyler Cloke <tyler@opscode.com>
#
# Usage: ruby s3-parse-manifest-json.rb s3-filenames-file s3-bucket-name s3-sub-bucket-name output-dir reversed-ruby (see reverse-release-json.rb for last arg help)
#
# Ruby script that parses .json manifest files from s3, downloads each file 
# endpoint in the json from s3 and stores them in the format required for 
# omnibus' RELEASE.rb script. See backup/README.md for details.
#
require "uber-s3"
require "json"
require "colorize"
require 'fileutils'

def parse_s3_manifest(json, reversed_json, output_root)
  # for each platform => plat_version => architecture => chef_version
  json.each                       do |platform, platform_value|
    platform_value.each             do |platform_version, platform_version_value| 
      platform_version_value.each     do |arch, arch_value|
        arch_value.each                 do |chef_version, chef_version_value|
          # get the name of the omnibus version dir
          omnibus_dir = reversed_json[platform][platform_version][arch]
          # get the output path in omnibus format (see readme if interested in format)
          output_dir = "#{output_root}/#{chef_version}/#{omnibus_dir}/pkg/"

          # get the name of the chef build file
          file_name = chef_version_value.split("/")[-1]
          
          # make output path and download file if output path doesn't exist
          if File.directory? output_dir
            puts  "Directory already exists, not downloading #{file_name}".yellow
            `echo "Directory already exists, not downloading #{file_name}" >> backup-error-log`
          else
            # make directory
            FileUtils.mkdir_p(output_dir)

            # download file from s3 into directory
            s3_file = chef_version_value.gsub(/\+/, "%2B")
            output_file = "#{output_dir}/#{file_name}"
            download_build_from_s3(s3_file, output_file)             
          end
        end
      end
    end
  end
end

def download_build_from_s3(s3_file, output_file)
  # rip that sucker down from s3 and into your output path, if you haven't dl-ed it yet
  begin
    `wget https://opscode-omnitruck-release.s3.amazonaws.com#{s3_file} -O #{output_file}`
  rescue
    puts  "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{s3_file} to file #{output_file}".red
    `echo "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{s3_file} to file #{output_file}" >> backup-error-log`
  end
end

if __FILE__ == $0
  # grab the s3 key from s3cfg
  SECRET_KEY=`grep secret_key ../config/s3cfg | cut -d ' ' -f 3`
  ACCESS_KEY=`grep access_key ../config/s3cfg | cut -d ' ' -f 3`

  s3 = UberS3.new({
                    :access_key         => ACCESS_KEY.strip,
                    :secret_access_key  => SECRET_KEY.strip,
                    :bucket             => ARGV[1],
                    :adapter            => :net_http
                  })

  # file where each line is a ruby release version
  file = File.open(ARGV[0]).read
  # inverse of omnibus-chef/jenkins/release.rb file
  reversed_json = JSON.parse(File.open(ARGV[4]).read)

  # for each release manifest
  file.each_line do |line|
    parts = line.split('/')
    # get the release manifest file name
    filename = "#{ARGV[2]}/#{parts[parts.length-1]}".strip

    file_found = false
    filename = filename.gsub(/\+/, "%2B") 
    begin
      # get the json from the current release manifest
      json = JSON.parse(s3.get(filename).value)
      file_found = true
    rescue
      puts  "COULD NOT OPEN S3 FILE #{filename}".red
      `echo "COULD NOT OPEN S3 FILE #{filename}" >> backup-error-log`
    end

    if file_found
      puts "Downloading all files from #{filename}".green
      parse_s3_manifest(json, reversed_json, ARGV[3])
    end
  end
end

