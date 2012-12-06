require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'pp'

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  class InvalidDownloadPath < StandardError; end
  configure do
    set :raise_errors, Proc.new { false }
    set :show_exceptions, false
    enable :logging
  end

  #
  # serve up the installer script
  #
  get '/install.sh' do
    content_type :sh
    erb :'install.sh', {
      :layout => :'install.sh',
      :locals => {
        :download_url => url("#{settings.virtual_path}/download")
      }
    }
  end

  error InvalidDownloadPath do
    status 404
    env['sinatra.error']
  end


  #
  # download an omnibus chef package
  #
  # == Params
  #
  # * :version:          - The version of Chef to download
  # * :platform:         - The platform to install on
  # * :platform_version: - The platfrom version to install on
  # * :machine:          - The machine architecture to install on
  #
  get '/download' do
    handle_download("chef-client", JSON.parse(File.read(settings.build_list)))
  end

  get '/download-server' do
    handle_download("chef-server", JSON.parse(File.read(settings.build_server_list)))
  end

  #
  # Returns the JSON minus run data to populate the install page build list
  #
  get '/full_client_list' do
    directory = JSON.parse(File.read(settings.build_list))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end

  #
  # TODO: redundant end-point to be deleted. Currently included for
  # backwards compatibility.
  #
  get '/full_list' do
    directory = JSON.parse(File.read(settings.build_list))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end


  #
  # Returns the server JSON minus run data to populate the install page build list
  #
  get '/full_server_list' do
    directory = JSON.parse(File.read(settings.build_server_list))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end

  #
  # Returns the server JSON minus run data to populate the install page build list
  #
  get '/chef_platform_names' do
    if File.exists?(settings.chef_platform_names)
      directory = JSON.parse(File.read(settings.chef_platform_names))
      JSON.pretty_generate(directory)
    else
      status 404
      env['sinatra.error']
      'File not found on server.'
    end
  end

  #
  # Returns the server JSON minus run data to populate the install page build list
  #
  get '/chef_server_platform_names' do
    if File.exists?(settings.chef_server_platform_names)
      directory = JSON.parse(File.read(settings.chef_server_platform_names))
      JSON.pretty_generate(directory)
    else
      status 404
      env['sinatra.error']
      'File not found on server.'
    end
  end


  #
  # Status endpoint used by nagios to check on the app.
  #
  get '/_status' do
    directory = JSON.parse(File.read(settings.build_list))
    status = { :timestamp => directory['run_data']['timestamp'] }
    JSON.pretty_generate(status)
  end



  # ---
  # HELPER METHODS
  # ---
  VERSION_REGEX = /^(\d+).(\d+).(\d+)-?(\d+)?$/
  VERSION_TEST_REGEX = /^(\d+).(\d+).(\d+)-(alpha|beta|rc)-(\d+)-(\w+)$/

  # Helper to turn a chef version into an array for comparison with other versions
  def version_to_array(v, include_test)
    # parse as the test regex only if 'include_test' is enabled.
    if include_test
      # e.g., 11.0.0-alpha-1-g092c123
      match = v.match(VERSION_TEST_REGEX)
      if match
        v_arr = match[1..6]
        # The things that are supposed to be integers should get
        # turned into integers, so they sort correctly.
        [0, 1, 2, 4].each do |i|
          v_arr[i] = v_arr[i].to_i
        end
      end
    end

    # otherwise, fall back to the normal regex.
    if !match
      # e.g., "10.14.4" or "10.16.2-1"
      match = v.match(VERSION_REGEX)
      if match
        v_arr = match[1..4]
        v_arr[3] ||= 0
        # The things that are supposed to be integers should get
        # turned into integers, so they sort correctly.
        v_arr.map! {|v| v.to_i}
      end
    end
    v_arr
  end

  # Take the input architecture, and an optional version (latest is
  # default), and redirect to an appropriate build. This is called for
  # both /download
  def handle_download(name, build_hash)
    chef_version     = params['v']
    platform         = params['p']
    platform_version = params['pv']
    machine          = params['m']
    include_test     = params['include-test']

    error_msg = "No #{name} installer for platform #{platform}, platform_version #{platform_version}, machine #{machine}"

    if !build_hash[platform] || !build_hash[platform][platform_version] || !build_hash[platform][platform_version][machine]
      raise InvalidDownloadPath, error_msg
    end

    # Pull out the map, which is a string version -> URL; Convert it
    # to a mapping of version_array -> URL.
    #         e.g. {"10.14.2-2" => "..."} 
    # would become {[10, 14, 2, 2] => "..."}
    versions_available = build_hash[platform][platform_version][machine]
    version_arrays_available = versions_available.keys.inject({}) do |res, version_string|
      # version_to_array will return nil if the version passed it
      # doesn't match the appropriate regex, and it will also filter
      # out test versions unless include_test is true.
      version_array = version_to_array(version_string, include_test)
      if version_array
        res[version_array] = versions_available[version_string]
      end
      res
    end

    # Rubygems considers any version with an alpha character to be a
    # non-stable release. Thus we will exclude these builds unless the
    # user explicitly chooses them
    if chef_version && ( chef_version.include?("-") || chef_version.match(/[[:alpha:]]/) )
      package_url = versions_available[chef_version]
    else
      # Turn the chef_version param into an array
      requested_version_array = if chef_version.nil? || chef_version == ""
                                  version_arrays_available.keys.max
                                else
                                  version_to_array(chef_version, include_test)
                                end

      # Find all of the iterations of the version matching the first three parts of chef_version
      matching_versions = version_arrays_available.keys.find_all {|v| v[0..2] == requested_version_array[0..2]}

      # Grabs the max iteration number
      requested_version_array = matching_versions.max_by {|v| v[-1]}

      # Now look it up based on the version we've found.
      package_url = version_arrays_available[requested_version_array]
    end

    # If we didn't find anything, throw an error.
    unless package_url
      raise InvalidDownloadPath, error_msg
    end

    base = "#{request.scheme}://#{settings.aws_bucket}.s3.amazonaws.com"
    redirect base + package_url
  end

end
