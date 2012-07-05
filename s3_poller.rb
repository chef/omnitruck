require 'uber-s3'
require 'json'

# Connect to S3

S3 = UberS3.new({
                  :access_key => "DONT",
                  :secret_access_key => "DO THIS AGAIN",
                  :bucket => 'opscode-full-stack',
                  :adapter => :net_http
                })

# List the available artifacts 

Artifact_directories = ['/debian-6.0.1-i686',
                        '/debian-6.0.1-x86_64',
                        '/el-5.7-i686',
                        '/el-5.7-x86_64',
                        '/el-6.2-i686',
                        '/el-6.2-x86_64',
                        '/mac_os_x-10.6.8-x86_64',
                        '/mac_os_x-10.7.2-x86_64',
                        #'/solaris2-5.9-sparc',
                        '/solaris2-5.11-i86pc',
                        '/ubuntu-10.04-i686',
                        '/ubuntu-10.04-x86_64',
                        '/ubuntu-11.04-i686',
                        '/ubuntu-11.04-x86_64']

Artifacts = Hash.new {|h,k| h[k] = Hash.new(&h.default_proc) }

def get_url(plat, plat_v, chef_v, arch, ext)
  # Like this http://opscode-full-stack.s3.amazonaws.com/ubuntu-11.04-x86_64/chef-full-0.10.4-1-ubuntu-11.04-x86_64.sh
  base = "http://opscode-full-stack.s3.amazonaws.com/"
  url = "#{base}#{plat}-#{plat_v}-#{arch}/chef-full-#{chef_v}-#{plat}-#{plat_v}-#{arch}#{ext}"
end

def get_artifacts(directories=Artifact_directories)
  directories.each do |dir|
    S3.objects(dir).each do |art|
      # get the useful information from the filename
      # s3 object doesn't provide a nice way to get this otherwise
      name = art.to_s.split(/\//)[1][0..-3]
      platform = dir[1..-1].split("-")[0]
      extension = name[/\.[[:alpha:]]+\z/]
      if extension == ".gz"
        if platform == "mac_os_x"
          extension = ".tar.gz"
        else
          next
        end
      elsif extension == ".sh"
        next
      else
        if platform == "mac_os_x"
          next
        end
      end
      platform_version = dir.split("-")[1]
      arch = dir.split("-")[2]
      chef_version = name[/\d+\.\d+\.\d+-?\d?+/].chomp("-")
      url = get_url(platform, platform_version, chef_version, arch, extension)
      Artifacts[platform][platform_version][arch][chef_version] = url
    end
  end
end

get_artifacts

File.open("test-tata.json", "w") do |f|
  f.puts JSON.pretty_generate(Artifacts)
end
