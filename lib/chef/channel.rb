class Chef
  class Channel
    attr_reader :name
    attr_reader :metadata_dir
    attr_reader :aws_metadata_bucket
    attr_reader :aws_packages_bucket

    def initialize(name, metadata_dir, aws_metadata_bucket, aws_packages_bucket)
      @name = name
      @metadata_dir = metadata_dir
      @aws_metadata_bucket = aws_metadata_bucket
      @aws_packages_bucket = aws_packages_bucket
    end

    def metadata_file(path)
      File.join(metadata_dir, path)
    end
  end
end
