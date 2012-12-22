require 'json'
require 'opscode/versions'

module Opscode

  # Simple tester module that can process omnitruck manifest JSON
  # files (either local files, or taken "live" from the production
  # Omnitruck) and validate our version parsing classes against the
  # versions that are currently available.
  module VersionTester

    CLIENT_URL = "http://www.opscode.com/chef/full_client_list"
    SERVER_URL = "http://www.opscode.com/chef/full_server_list"
    
    def self.current_client_versions
      versions_from_url(CLIENT_URL)
    end
    
    def self.current_server_versions
      versions_from_url(SERVER_URL)
    end
    
    def self.versions_from_url(url)
      data = JSON.parse(`curl --silent #{url}`)
      unique_versions(data)
    end
    
    def self.versions_from_file(file)
      data = JSON.parse(File.read(file))
      unique_versions(data)
    end
    
    def self.unique_versions(data)
      (data.keys.map do |platform|
         versions = data[platform]
         versions.keys.map do |version|
           architectures = data[platform][version]
           architectures.keys.map do |architecture|
             installers  = data[platform][version][architecture]
             installers.keys
           end
         end 
       end).flatten.sort.uniq
    end
    
    def self.test_with_version(version_class)
      version_strings = current_client_versions | current_server_versions
      
      valid, invalid = [], []
      
      version_strings.each do |v|
        begin
          ver = version_class.new(v)
          valid << ver
        rescue
          invalid << v
        end
      end
      
      puts "Results for #{version_class}"
      puts
      puts "Valid Versions ======================="
      valid.each{|v| show_version_internals(v)}
      puts
      puts "Invalid Versions ====================="
      invalid.each{|v| puts "\t#{v}"}
      puts
    end
    
    def self.show_version_internals(v)
      puts "\t#{v} = #{v.class}"
      puts "\tmajor      = #{v.major}"
      puts "\tminor      = #{v.minor}"
      puts "\tpatch      = #{v.patch}"
      puts "\tprerelease = #{v.prerelease}"
      puts "\tbuild      = #{v.build}"
      puts
    end

    def self.test_all
      version_strings = current_client_versions | current_server_versions
      
      valid, invalid = [], []
      
      # This is horrible, but necessary to sanely handle the current
      # variation we see.
      version_strings.each do |v|
        begin
          if v.start_with?("10.")
            begin 
              ver = Opscode::Versions::RubygemsVersion.new(v)
              valid << ver
            rescue
              ver = Opscode::Versions::GitDescribeVersion.new(v)
              valid << ver
            end
          elsif v.start_with?("11.")
            begin
              ver = Opscode::Versions::GitDescribeVersion.new(v)
              valid << ver
            rescue
              begin
                ver = Opscode::Versions::OpscodeSemVer.new(v)
                valid << ver
              rescue
                ver = Opscode::Versions::SemVer.new(v)
                valid << ver
              end
            end
          end
        rescue
          invalid << v
        end
      end
      
      puts "Results for All Version Styles"
      puts
      puts "Valid Versions ======================="
      valid.each{|v| show_version_internals(v)}
      puts
      puts "Invalid Versions ====================="
      invalid.each{|v| puts "\t#{v}"}
      puts
      puts "Sorting Order ========================"
      valid.sort.each{|v| puts "\t#{v}"}
      puts
      puts "Releases ============================="
      valid.select(&:release?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Pre-Releases ========================="
      valid.select(&:prerelease?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Release Nightlies (Builds) ==========="
      valid.select(&:release_nightly?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Pre-release Nightlies (Builds) ======="
      valid.select(&:prerelease_nightly?).sort.each{|v| puts "\t#{v}"}
      puts

    end
  end
end

