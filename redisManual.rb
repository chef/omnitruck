require "redis"
require "json"

class ChefDevLocal
  class CacheLocal
    def initialize()
      # env var REDIS_URL is required here
      redis_url = ENV['REDIS_URL']
      @redis = Redis.new(url: redis_url)
    end

    def load_data_into_redis
      Dir.glob('spec/data/*') do |file|
        next unless File.file?(file)

        begin
          data = JSON.parse(File.read(file))

          data.each do |key, value|
            @redis.set(key, value)
          end

          puts "Loaded data from #{file} into Redis."
        rescue JSON::ParserError => e
          puts "Failed to parse #{file}: #{e.message}"
        rescue => e
          puts "Error loading data from #{file}: #{e.message}"
        end
      end
    end

    # method to display the redis cache locally
    def display_data_from_redis
      raise "Redis connection not initialized" if @redis.nil?

      keys = @redis.keys('*')

      if keys.empty?
        puts "No data found in Redis."
      else
        keys.each do |key|
          value = @redis.get(key)
          puts "#{key}: #{value}"
        end
      end
    end
  end
end

# run the things
cache = ChefDevLocal::CacheLocal.new
cache.load_data_into_redis

#un comment this if you want to see the cache locally in redis. 
# cache.display_data_from_redis
