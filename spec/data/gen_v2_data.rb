# gen_v2_data.rb
# usage: ruby gen_v2_data.rb V1_FILE
# (prints to stdout)
# To write generated v2 data for use w/ specs:
# ruby gen_v2_data.rb V1_FILE > V2_FILE

require 'rubygems'
require 'yajl'
require 'digest'
require 'stringio'
require 'pp'

def md5(string)
  digest(Digest::MD5, StringIO.new(string))
end

def sha256(string)
  digest(Digest::SHA256, StringIO.new(string))
end

def digest(digest_class, io)
  digest = digest_class.new
  while chunk = io.read(1024 * 8)
    digest.update(chunk)
  end
  digest.hexdigest
end


v1_client = Yajl::Parser.parse(ARGF.read)
v1_client.delete("run_data")
v1_client.each_value do |builds_by_distro_version|
  builds_by_distro_version.each_value do |builds_by_arch|
    builds_by_arch.each_value do |pkgs_by_version|
      pkgs_by_version.each do |pkg_ver, relpath|
        v2_data = {:relpath => relpath, :md5 => md5(relpath), :sha256 => sha256(relpath) }
        pkgs_by_version[pkg_ver] = v2_data
      end
    end
  end
end

begin
  puts Yajl::Encoder.encode(v1_client, :pretty => true)
rescue Errno::EPIPE
  exit 0
end
