class Chef
  class Project
    attr_reader :name
    attr_reader :build_list_v1
    attr_reader :build_list_v2
    attr_reader :platform_names

    def initialize(name, channel, build_list_v1, build_list_v2, platform_names)
      @name = name
      @channel = channel
      @build_list_v1 = build_list_v1
      @build_list_v2 = build_list_v2
      @platform_names = platform_names
    end

    def self.load(name, channel)
      Chef::Project.new(
        name,
        channel,
        channel.metadata_file("build_#{name}_list_v1.json"),
        channel.metadata_file("build_#{name}_list_v2.json"),
        channel.metadata_file("#{name}_platform_names.json")
      )
    end
  end
end
