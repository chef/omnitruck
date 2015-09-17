require 'chef/project'

class Chef
  class ProjectCache
    attr_reader :project
    attr_reader :metadata_dir

    def initialize(project, metadata_dir)
      @project = project
      @metadata_dir = metadata_dir
    end

    def update
      update_cache
      json_v2 = generate_combined_manifest

      write_data(build_list_v2_path, json_v2)
      write_data(build_list_v1_path, parse_to_v1_format!(json_v2))

      File.open(platform_names_path, "w") do |f|
        f.puts project.get_platform_names
      end
    end

    def name
      project.name
    end

    def build_list_v1_path
      metadata_file("build-#{project.name}-list-v1.json")
    end

    def build_list_v2_path
      metadata_file("build-#{project.name}-list-v2.json")
    end

    def platform_names_path
      metadata_file("#{project.name}-platform-names.json")
    end

    def self.for_project(project_name, channel, metadata_dir)
      project = Chef::Project.new(project_name, channel)
      Chef::ProjectCache.new(project, metadata_dir)
    end

    private

    # parses v2 JSON format to v1 format
    def parse_to_v1_format!(json)
      # discusting nested loops, but much easier than writing a generic DFS solution or something
      json.each do |platform, platform_value|
        next if platform.to_s == "run_data"
        platform_value.each_value do |platform_version_value|
          platform_version_value.each_value do |architecture_value|
            architecture_value.each do |chef_version, chef_version_value|
              architecture_value[chef_version] = chef_version_value["relpath"]
            end
          end
        end
      end
    end

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
      manifests_to_fetch = project.manifests - local_manifests
      debug("Files to delete:\n#{manifests_to_delete.map{|f| "* #{f}"}.join("\n")}")
      debug("Files to fetch:\n#{manifests_to_fetch.map{|f| "* #{f}"}.join("\n")}")
      manifests_to_delete.each {|m| delete_manifest(m) }
      manifests_to_fetch.each {|f| fetch_manifest(f) }
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
