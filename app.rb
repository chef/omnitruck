require 'sinatra'
require 'json'

class InvalidPlatform < StandardError; end
class InvalidPlatformVersion < StandardError; end
class InvalidMachine < StandardError; end
class InvalidChefVersion < StandardError; end

set :raise_errors, Proc.new { false }
set :show_exceptions, false

#
# serve up the installer script
#
get '/install.sh' do
  send_file 'install.sh'
end

# Errors to handle bad params
error InvalidPlatform do
  status 404
  "#{env['sinatra.error'].message.capitalize} is an invalid platform, please try again."
end

error InvalidPlatformVersion do
  status 404
  p_v = env['sinatra.error'].message.split(":")[0]
  p = env['sinatra.error'].message.split(":")[1]
  "#{p_v} is an invalid platform version for #{p.capitalize}, please try again."
end

error InvalidMachine do
  status 404
  "#{env['sinatra.error'].message} is an invalid machine architecture, please try again."
end

error InvalidChefVersion do
  status 404
  "#{env['sinatra.error'].message} is an invalid Chef version, please try again."
end

#
# download an omnibus chef package
#
# == Params
#
# * :version:          - The version of Chef to download
# * :platform:         - The platform to install on
# * :platform_version: - The platfrom version to install on
#
get '/download' do
  chef_version     = params['v']
  platform         = params['p']
  platform_version = params['pv']
  machine          = params['m']
  f = File.read('directory.json')
  directory = JSON.parse(f)
  platform_dir = directory[platform]
  raise InvalidPlatform, platform if platform_dir.nil?
  plat_version_dir = platform_dir[platform_version]
  raise InvalidPlatformVersion, "#{platform_version}:#{platform}" if plat_version_dir.nil?
  machine_dir = plat_version_dir[machine]
  raise InvalidMachine, machine if machine_dir.nil?
  chef_version = latest_version(machine_dir.keys) if chef_version.nil?
  url = machine_dir[chef_version]
  raise InvalidChefVersion, chef_version if url.nil?
  redirect url
end

def latest_version(versions)
  latest = '0.0.0'
  versions.each do |v|
    latest = which_bigger(v, latest)
  end
  latest
end

# Requires version of the form /\d+\.\d+\.\d+-?\d?+/
#                          eg. 0.10.8, 10.12.0-1

def which_bigger(a, b)
  a_iter = 0
  b_iter = 0
  result = nil
  if a.include?("-")
    a_iter = (a.split("-")[1])
    a = a.split("-")[0]
  end
  if b.include?("-")
    b_iter = (b.split("-")[1])
    b = b.split("-")[0]
  end
  a_parts = a.split(".")
  b_parts = b.split(".")
  (0..2).each do |i|
    Integer(a_parts[i]) > Integer(b_parts[i]) ? (result = "#{a}-#{a_iter}") : (result = "#{b}-#{b_iter}") unless a_parts[i] == b_parts[i]
    break if !result.nil?
  end
  # if execution gets here, aa.aa.aa = bb.bb.bb, go to iteration
  Integer(a_iter) > Integer(b_iter) ? (result = "#{a}-#{a_iter}") : (result = "#{b}-#{b_iter}") if result.nil?
  if result[-1] == '0'
    result = result.split("-")[0]
  end
  result
end
