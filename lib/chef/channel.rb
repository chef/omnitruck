require 'chef/bucket_lister'

class Chef
  class Channel
    class ManifestNotFound < Exception; end

    KNOWN_CHANNELS = %w( current stable )

    attr_reader :name
    attr_reader :aws_metadata_bucket
    attr_reader :aws_packages_bucket
    attr_reader :manifest_metadata
    attr_reader :s3

    def initialize(name, aws_metadata_bucket, aws_packages_bucket)
      @name = name
      @aws_metadata_bucket = aws_metadata_bucket
      @aws_packages_bucket = aws_packages_bucket
      @manifest_metadata = {}

      @s3 = Chef::BucketLister.new(aws_metadata_bucket)
    end

    # Return all release manifests in the s3 bucket for the given channel
    def manifests
      @manifests ||= begin
                           s3.fetch do |key, md5, last_modified|
                             @manifest_metadata[key] = { md5: md5, last_modified: last_modified }
                           end
                           @manifest_metadata.keys.select do |k|
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

    def manifest_md5_for(key)
      manifest_metadata.key?(key) ? manifest_metadata[key][:md5] : nil
    end

    def manifest_last_modified_for(key)
      manifest_metadata.key?(key) ? manifest_metadata[key][:last_modified] : nil
    end
  end
end
