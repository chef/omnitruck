require "redis"
require "json"

class ChefDevLocal
  class CacheLocal
    def initialize()
      redis_url = ENV['REDIS_URL'] # this is local value set in export redis://ip:6379"
      @redis = Redis.new(url: redis_url)
    end

    def load_data_into_redis
      parent_dir = 'spec/data'

      # Iterate through the things
        Dir.glob("#{parent_dir}/*/") do |sub_dir|
          project = File.basename(sub_dir.chomp('/'))

            # Iterate through each json stuff
            Dir.glob("#{sub_dir}*.json") do |file|
              next unless File.file?(file)

                begin
                  data = JSON.parse(File.read(file))

                    channel = File.basename(file, ".json")

                    manifest = ProjectManifest.new(project, channel)

                    manifest.data = data  # Assuming you have a way to set data in ProjectManifest

                    @redis.set("#{channel}/#{project}", manifest.serialize)

                        puts "Loaded data from #{file} into Redis for project '#{project}' and channel '#{channel}'."
                rescue JSON::ParserError => e
                  puts "Failed to parse #{file}: #{e.message}"
                rescue => e
                  puts "Error loading data from #{file}: #{e.message}"
                end
            end
        end
    end

    # show me the DATA!
    def print_all_keys
      keys = @redis.keys('*')
         if keys.empty?
           puts "No data found in Redis."
        else
          keys.each do |key|
            puts key
            end
         end
    end
  end
end

# Run the things
cache = ChefDevLocal::CacheLocal.new
cache.load_data_into_redis
cache.print_all_keys
