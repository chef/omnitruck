require 'chef/project'
require 'chef/version'
require 'digest'

class Chef
  class ProjectCache
    attr_reader :project
    attr_reader :metadata_dir

    def initialize(project, metadata_dir)
      @project = project
      @metadata_dir = metadata_dir
    end

    # This method ensures that we do not have i686 as architecture in manifests.
    # We are not supposed to have it anyways but maybe some older version of
    # projects still has it.
    def fix_windows_manifest!(manifest)
      return manifest if manifest['windows'].nil?

      builds_32bit = {}
      builds_64bit = {}

      manifest['windows'].each do |platform_version, build_data|
        build_data.each do |architecture, builds|
          builds.each do |version, build|
            case architecture
            when 'x86_64'
              if %w{chef angrychef}.include?(project.name)
                if Opscode::Version.parse(version) <= Opscode::Version.parse("12.6.0")
                  # Including and prior to Chef 12.6.0 we only had 1 Windows build that worked for
                  # all architectures and versions.  It was a 32-bit build but was sometimes
                  # marked in the 64-bit manifest, so we need to copy all old 64-bit builds
                  # into the 32-bit manifest.
                  builds_32bit[version] = build
                else
                  # Now that we _actually_ have 64-bit builds we also want to
                  # exclude all the old 32-bit builds from the 64-bit manifest
                  builds_64bit[version] = build
                end
              elsif project.name == 'chefdk'
                # ChefDK is still only built to produce a 32-bit package.  But like Chef,
                # it works on both 32-bit systems and 64-bit systems.  It also may
                # sometimes be tagged as x86_64 or i386.  But we want to use each
                # package for all customer architectures.
                builds_32bit[version] = build
                builds_64bit[version] = build
              else
                builds_64bit[version] = build
              end
            when 'i386', 'i686'
              builds_32bit[version] = build
              if project.name == 'chefdk'
                builds_64bit[version] = build
              end
            else
              raise "Unknown Windows architecture '#{architecture}'"
            end
          end
        end
      end

      manifest['windows'] = {
        '2008r2' => {
          'i386'   => builds_32bit,
          'x86_64' => builds_64bit
        }
      }

      manifest
    end

    def update
      update_cache

      json_v2 = fix_windows_manifest!(generate_combined_manifest)

      write_data(build_list_path, json_v2)

      File.open(platform_names_path, "w") do |f|
        f.puts project.get_platform_names
      end
    end

    def name
      project.name
    end

    def build_list_path
      metadata_file("build-#{name}-list.json")
    end

    def platform_names_path
      metadata_file("#{name}-platform-names.json")
    end

    def self.for_project(project_name, channel, metadata_dir)
      project = Chef::Project.new(project_name, channel)
      Chef::ProjectCache.new(project, metadata_dir)
    end

    def timestamp
      JSON.parse(File.read(build_list_path))['run_data']['timestamp']
    end

    private

    def write_data(path, data)
      data[:run_data] = { :timestamp => Time.now.to_s }
      File.open(path, "w") { |f| Yajl::Encoder.encode(data, f, :pretty => true) }
    end

    def generate_combined_manifest
      # after updating cache, we have the same manifests as remote
      project.manifests.inject({}) do |combined_manifest_data, manifest|
        manifest_file = cache_path_for_manifest(manifest)
        manifest_data = Yajl::Parser.parse(File.read(manifest_file))
        deep_merge(combined_manifest_data, manifest_data)
      end
    end

    def update_cache
      create_cache_dirs
      manifests_to_delete = local_manifests - project.manifests
      debug("Files to delete:\n#{manifests_to_delete.map{|f| "* #{f}"}.join("\n")}")
      debug("Files to fetch:\n#{manifests_to_fetch.map{|f| "* #{f}"}.join("\n")}")
      manifests_to_delete.each {|m| delete_manifest(m) }
      manifests_to_fetch.each {|f| fetch_manifest(f) }
    end

    def manifests_to_fetch
      @fetch_list ||= project.manifests.select { |manifest| should_fetch_manifest?(manifest) }
    end

    def should_fetch_manifest?(manifest)
      if !local_manifest_exists?(manifest)
        true
      elsif have_both_md5s_for?(manifest)
        !manifest_md5_matches?(manifest)
      else
        remote_manifest_newer?(manifest)
      end
    end

    def local_manifest_exists?(manifest)
      File.exist?(cache_path_for_manifest(manifest))
    end

    def local_manifest_md5_for(manifest)
      return unless local_manifest_exists?(manifest)
      Digest::MD5.file(cache_path_for_manifest(manifest))
    end

    def have_both_md5s_for?(manifest)
      !local_manifest_md5_for(manifest).nil? && !project.manifest_md5_for(manifest).nil?
    end

    def manifest_md5_matches?(manifest)
      local_manifest_md5_for(manifest) == project.manifest_md5_for(manifest)
    end

    def local_manifest_mtime(manifest)
      return unless local_manifest_exists?(manifest)
      File.mtime(cache_path_for_manifest(manifest))
    end

    def remote_manifest_newer?(manifest)
      local  = local_manifest_mtime(manifest)
      remote = project.manifest_last_modified_for(manifest)

      if !local
        true
      elsif !remote
        false
      else
        remote > local
      end
    end

    def fetch_manifest(manifest)
      local_path = cache_path_for_manifest(manifest)
      File.open(local_path, "w+") do |f|
        f.print project.download_manifest(manifest)
      end
    rescue Exception
      File.unlink(local_path) if local_path && File.exist?(local_path)
      raise
    end

    def create_cache_dirs
      FileUtils.mkdir_p(cache_dir, mode: 0700)
    end

    def delete_manifest(manifest)
      File.unlink(cache_path_for_manifest(manifest))
    end

    def cache_dir
      metadata_file("release-metadata-cache/#{project.release_manifest_name}")
    end

    def metadata_file(path)
      File.join(metadata_dir, project.channel.name, path)
    end

    def cache_path_for_manifest(manifest_name)
      File.join(cache_dir, manifest_name)
    end

    def local_manifests
      Dir["#{cache_dir}/*"].map { |m| File.basename(m) }
    end

    # Define a deep merge for nested hashes
    def deep_merge(h1, h2)
      result = h1.dup
      h2.keys.each do |key|
        result[key] = if h1[key].is_a? Hash and h2[key].is_a? Hash
                        deep_merge(result[key], h2[key])
                      else
                        h2[key]
                      end
      end
      result
    end

    def debug(message)
      # TODO: turn this off for cron
      puts message
    end
  end
end
