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
  url = machine_dir[chef_version]
  raise InvalidChefVersion, chef_version if url.nil?
  redirect url
end
