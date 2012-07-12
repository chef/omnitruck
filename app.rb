require 'sinatra'
#* #### OC-2101
#*
#* The sinatra-contrib gem is not included in the Gemfile.
#* Gemfiles are used by `bundler`, which we use to manage gem
#* dependencies on all of our development and production servers. What
#* will happen if we don't include the dependency in the Gemfile is
#* that our service will fail to start when we deploy it to production
#* because it won't be able to find the required gems. To fix this:
#*
#* * add "gem sinatra-config" to the Gemfile
#* * run `bundle install`
#* * check in both Gemfile and Gemfile.lock
#*
require 'sinatra/config_file'
require 'json'

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  class InvalidPlatform < StandardError; end
  class InvalidPlatformVersion < StandardError; end
  class InvalidMachine < StandardError; end
  class InvalidChefVersion < StandardError; end

  set :raise_errors, Proc.new { false }
  set :show_exceptions, false

  RACK_ENV = "development"

  #
  # serve up the installer script
  #
  get '/install.sh' do
    content_type :sh
    erb :'install.sh', { :layout => :'install.sh', :locals => { :base_url => settings.base_url } }
  end

  #* #### OC-2103
  #*
  #* I'm not sure we need 4 individual errors here. It adds a bit of
  #* complicated logic in the controller for little benefit. What
  #* would be sufficent would be a single 404 with a message "No
  #* chef-client $version installer for $platform-$platform_version-$machine"
  #*
  #* The only consumer of this service is going to be the `install.sh`
  #* script, so we don't need to get really fancy here.
  #*

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

  #* #### OC-2105
  #*
  #* the method signature comments should be updated to refelct the
  #* fact that we take a new additional requests parameter: m
  #*
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

    #* #### OC-2106
    #*
    #* right here, the name of the file is `build_list.json`, but the
    #* s3 poller utility we pass the filename in as a command
    #* line argument. This means that to change the location of this
    #* file, we'll have to change this both here in the controller and
    #* in the cookbook that generates the cron job and the initial
    #* execution. We should instead have the source of truth be in one
    #* location, most likely a configuration file written by the
    #* cookbook
    #*
    #* we could most likely re-use the yaml file for the sinatra
    #* config. yaml is easy enough to parse from the s3 poller script
    #* as well
    #*
    f = File.read('build_list.json')
    directory = JSON.parse(f)
    platform_dir = directory[platform]
    raise InvalidPlatform, platform if platform_dir.nil?
    plat_version_dir = platform_dir[platform_version]
    raise InvalidPlatformVersion, "#{platform_version}:#{platform}" if plat_version_dir.nil?
    machine_dir = plat_version_dir[machine]
    raise InvalidMachine, machine if machine_dir.nil?
    if chef_version.nil?
      chef_version = latest_version(machine_dir.keys)
    elsif !chef_version.include?("-")
      chef_version = latest_iteration(machine_dir.keys, chef_version)
    end
    url = machine_dir[chef_version]
    raise InvalidChefVersion, chef_version if url.nil?
    redirect url
  end

  # Returns the latest chef version from a list
  def latest_version(versions)
    latest = '0.0.0'
    versions.each do |v|
      latest = which_bigger(v, latest)
    end
    latest
  end

  # Returns the most recent chef version of the two passed in
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
      #* #### Holy Shit
      #*
      #* we need to have a chat
      #*
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

  # grabs the latest iteration of a given version of chef
  def latest_iteration(versions, chef_version)
    c_v = chef_version
    versions.each do |v|
      if v.include?(chef_version)
        if v.include?("-")
          if c_v.include?("-")
            Integer(v.split("-")[1]) > Integer(c_v.split("-")[1]) ? (c_v = v) : (c_v)
          else
            c_v = v
          end
        end
      end
    end
    c_v
  end
end
