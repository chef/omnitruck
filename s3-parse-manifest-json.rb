# Author: Tyler Cloke <tyler@opscode.com>
# Usage: ruby s3-parse-manifest-json.rb s3-filenames-file s3-access-key s3-secret-key s3-bucket-name s3-sub-bucket-name output-dir
#
#
# Ruby script that parses .json files from s3, downloads each file endpoint in the json from s3
# and stores them in the format required for omnibus' RELEASE.rb script.
#
require "uber-s3"
require "JSON"
require "colorize"

s3 = UberS3.new({
  :access_key         => ARGV[1],
  :secret_access_key  => ARGV[2],
  :bucket             => ARGV[3],
  :adapter            => :net_http
})

file = File.open(ARGV[0]).read

file.each_line do |line|
  parts = line.split('/')
  filename = "#{ARGV[4]}/#{parts[parts.length-1]}".strip
  json = JSON.parse(s3.get(filename).value)
  puts "Downloading all files from #{filename}"
  
  json.each do |platform, platform_value| 
    platform_value.each do |platform_version, platform_version_value| 
      platform_version_value.each do |arch, arch_value|
        arch_value.each do |chef_version, chef_version_value|
          # TODO: pretty sure this is not how we want to save the files, but WIP

          # convert platform to something release.rb can hopefully understand
          temp_version = platform_version.clone
          temp_version["."]="-" if temp_version["."]

          # convert arch from manifest version to release.rb version
          arch = "x64"   if arch == "x86-64"
          arch = "intel" if arch == "i386"
          arch = "x86"   if arch == "i686"
          if /server/.match(chef_version_value).nil?
            role = "oss-builder"
          else
            role = "builder"
          end
          output_file = "#{ARGV[5]}/build_os=#{platform}-#{temp_version},machine_architecture=#{arch},role=#{role}"
          begin
            `wget https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} -O #{output_file}`
          rescue
            puts "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} to file #{output_file}".red
            `echo "Failed to download https://opscode-omnitruck-release.s3.amazonaws.com#{chef_version_value} to file #{output_file}" >> backup-error-log`
          end
        end
      end
    end        
  end
end
