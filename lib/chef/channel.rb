require 'chef/bucket_lister'

class Chef
  class Channel
    class ManifestNotFound < Exception; end

    KNOWN_CHANNELS = %w( current stable )

    attr_reader :name
    attr_reader :aws_metadata_bucket
    attr_reader :aws_packages_bucket

    def initialize(name, aws_metadata_bucket, aws_packages_bucket)
      @name = name
      @aws_metadata_bucket = aws_metadata_bucket
      @aws_packages_bucket = aws_packages_bucket

      @s3 = Chef::BucketLister.new(aws_metadata_bucket)
    end

    # Return all release manifests in the s3 bucket for the given channel
    def manifests
      @manifests ||= begin
                           keys = []
                           @s3.fetch do |key, md5|
                             keys << key
                           end
                           @all_manifests = keys.select do |k|
                             k =~ /\.json\Z/ and k !~ /platform-names.json/
                           end
                         end
    end

    def download_manifest(manifest)
      url = s3_url_for_manifest(manifest)
      debug "Fetching from #{url}"
      RestClient.get(url)
    rescue RestClient::Exception => e
      debug "Error fetching #{url}"
      debug(e)
      if e.http_code == 404
        raise ManifestNotFound
      else
        raise
      end
    end

    def s3_url_for_manifest(key)
      key = key.gsub(/\+/, "%2B")
      "https://#{aws_metadata_bucket}.s3.amazonaws.com/#{key}"
    end

    def debug(msg)
      puts msg
    end
  end
end
