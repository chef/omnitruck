# Author Tyler Cloke <tyler@opscode.com>
#
# Reverses omnibus-chef/jenkins/chef.json or chef-server.json from format:
# 
#"build_os=centos-5,machine_architecture=x64,role=oss-builder": [
#       [
#            "el",
#            "5",
#            "x86_64"
#        ]
#
# to format:
# "el": {
#    "5": {
#      "x86_64": "build_os=centos-5,machine_architecture=x64,role=oss-builder",
#      "i686": "build_os=centos-5,machine_architecture=x86,role=oss-builder"
#    }
#
# and outputs to "reversed.json"
require 'json'

json = {}
input = JSON.parse(File.read(ARGV[0]))
input.each do |key, array|
  array.each do |block|
    json[block[0]] ||= {}
    json[block[0]][block[1]] ||= {}
    json[block[0]][block[1]][block[2]] ||= {}
    json[block[0]][block[1]][block[2]] = key
  end
end

File.open("reversed.json", "w") do |f|
  f.write(JSON.pretty_generate(json))
end


