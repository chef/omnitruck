#!/usr/bin/env ruby
# Seeds Redis with test fixture data so integration specs run without
# making network calls to packages.chef.io.
#
# Usage:
#   bundle exec ruby spec/support/seed_redis.rb
#
# Key format matches what Chef::Cache / poller writes: "<channel>/<project>"

require "redis"
require "json"

SPEC_DATA = File.expand_path("../../data", __FILE__)

redis_url = ENV["REDIS_URL"]
redis = redis_url && !redis_url.empty? ? Redis.new(url: redis_url) : Redis.new
count = 0
Dir["#{SPEC_DATA}/**/*-manifest.json"].sort.each do |file|
  m = file.match(%r{/data/(\w+)/(.+)-manifest\.json$})
  next unless m

  channel = m[1]
  project = m[2]
  key     = "#{channel}/#{project}"

  redis.set(key, File.read(file))
  puts "Seeded #{key}"
  count += 1
end

puts "\nDone — seeded #{count} keys into Redis"
