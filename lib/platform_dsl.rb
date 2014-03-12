
class PlatformDSL
  attr_accessor :platform_version_collection

  class PlatformVersion
    include Comparable

    attr_accessor :version

    def initialize(version)
      @version = version.dup
    end

    def mapped_version
      if version_remap.nil?
        version
      elsif version_remap.is_a?(Proc)
        version_remap.call(version)
      else
        version_remap
      end
    end

    def mapped_name
      remap || name
    end

    # these functions operate on the given version that has not been remapped
    def matchdata
      /^([^\.]*)(\.([^\.]*))*/.match(version)
    end

    def major
      matchdata[1]
    end

    def minor
      matchdata[2]
    end

    def patch
      matchdata[3]
    end

    # these functions operate on the remapped distro version
    def mapped_matchdata
      /^([^\.]*)(\.([^\.]*))*/.match(mapped_version)
    end

    def mapped_major
      mapped_matchdata[1]
    end

    def mapped_minor
      mapped_matchdata[2]
    end

    def mapped_patch
      mapped_matchdata[3]
    end

    def name
      raise NotImplementedError, "must be implemented by subclass"
    end
    def major_only
      raise NotImplementedError, "must be implemented by subclass"
    end
    def yolo
      raise NotImplementedError, "must be implemented by subclass"
    end
    def remap
      raise NotImplementedError, "must be implemented by subclass"
    end
    def version_remap
      raise NotImplementedError, "must be implemented by subclass"
    end

    def self.is_integer?(val)
      !!(val =~ /^[-+]?[0-9]+$/)
    end

    # We may have versions with strings (e.g. "2008r2") that we can't ignore, so only use
    # integer sorting when we know we have integer sorting (and this might need to be extended
    # to be smarter at some point and have different functions for different platforms)
    def favor_integer_sorting(a, b)
      if self.class.is_integer?(a) && self.class.is_integer?(b)
        a.to_i <=> b.to_i
      else
        a <=> b
      end
    end

    # platform versions may match when the strings do not match, sort order may not be what
    # you expect if you're trying to compare minor versions of EL/SuSE/etc...
    def <=>(otherVer)
      raise "comparison between incompatible platform versions:\n#{self}#{otherVer}" if self.mapped_name != otherVer.mapped_name
      if (major_only)
        favor_integer_sorting(self.mapped_major, otherVer.mapped_major)
      else
        ret = favor_integer_sorting(self.mapped_major, otherVer.mapped_major)
        ret = favor_integer_sorting(self.mapped_minor, otherVer.mapped_minor) if ret == 0 && self.mapped_minor
        ret = favor_integer_sorting(self.mapped_patch, otherVer.mapped_patch) if ret == 0 && self.mapped_patch
        ret
      end
    end


    def inspect
      "name:           #{name}\n" +
      "version:        #{version}\n" +
      "mapped name:    #{mapped_name}\n" +
      "mapped version: #{mapped_version}\n" +
      "major_only:     #{major_only}\n" +
      "yolo:           #{yolo}\n"
    end
  end

  class FileDSL
    attr_accessor :platform_dsl

    def initialize(platform_dsl)
      @platform_dsl = platform_dsl
    end

    def platform(name, &block)
      platform_spec = Class.new(PlatformDSL::PlatformSpec).new(name)
      platform_spec.instance_eval(&block) if block_given?
      platform_dsl.build(platform_spec)
    end
  end

  class PlatformSpec
    def initialize(name)
      @name = name
      @major_only = false
      @yolo = false
      @remap = nil
      @version_remap = nil
    end

    def name(opt = nil)
      unless opt.nil?
        raise "name must be a string" unless opt.instance_of?(String)
        @name = opt
      end
      @name
    end

    def major_only(opt = nil)
      unless opt.nil?
        raise "major_only must be true or false" unless opt.instance_of?(TrueClass) || opt.instance_of?(FalseClass)
        @major_only = opt
      end
      @major_only
    end

    def remap(opt = nil)
      unless opt.nil?
        raise "remapped platform name must be a string" unless opt.instance_of?(String)
        @remap = opt
      end
      @remap
    end

    def version_remap(opt = nil, &block)
      if !opt.nil? || block_given?
        if !opt.nil?
          raise "remapped platform version must be a string or numeric" unless opt.instance_of?(String) || opt.is_a?(Numeric)
          @version_remap = opt.to_s
        elsif block_given?
          @version_remap = block
        end
      end
      @version_remap
    end

    def yolo(opt = nil)
      unless opt.nil?
        raise "yolo must be true or false" unless opt.instance_of?(TrueClass) || opt.instance_of?(FalseClass)
        @yolo = opt
      end
      @yolo
    end
  end

  def initialize
    @platform_version_collection = []
  end

  def build(platform_spec)
    klass = Class.new(PlatformDSL::PlatformVersion)
    name = platform_spec.name
    major_only = platform_spec.major_only
    remap = platform_spec.remap
    version_remap = platform_spec.version_remap
    yolo = platform_spec.yolo
    klass.class_eval do
      define_singleton_method :name do name end
      define_method :name do name end
      define_method :major_only do major_only end
      define_method :remap do remap end
      define_method :version_remap do version_remap end
      define_method :yolo do yolo end
    end
    add_platform_version(klass)
  end

  def add_platform_version(klass)
    platform_version_collection.push(klass)
  end

  def find_platform_version(platform)
    platform_version_collection.select {|klass| klass.name == platform}.first
  end

  def new_platform_version(platform, version)
    klass = find_platform_version(platform)
    klass.new(version)
  end

  def from_file(filename)
    Class.new(PlatformDSL::FileDSL).new(self).instance_eval(IO.read(filename), filename, 1)
  end
end

