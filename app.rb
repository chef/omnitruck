require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'pp'

require 'opscode/semver'

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

  #  
  # +version_hash+: a hash of SemVer object to URL path
  #
  # +given_version+: String form of a semantic version that we can use
  # for filtering.  If it is a release version (e.g. "1.0.0"), we'll
  # keep only versions from the hash that share the same major, minor,
  # and patch versions.  If it's a pre-release
  def filter_semvers(version_hash, given_version, prerelease, use_nightlies)

    filtering_version = if given_version.nil? || given_version == "latest"
                          nil
                        else
                          Opscode::SemVer.new(given_version)
                        end

    # If we've requested a nightly (whether for a pre-release or release),
    # there's no sense doing any other filtering
    if filtering_version && filtering_version.nightly?
      return version_hash[filtering_version]
    end

    # If we've requested a prerelease, we only need to see if we want
    # a nightly or not.  If so, keep only the nightlies for that
    # prerelease, and then take the most recent.  Otherwise, just
    # return the specified prerelease version
    if filtering_version && filtering_version.prerelease?
      if use_nightlies
        filtered = version_hash.select do |version, url_path|
          filtering_version.in_same_release_tree(version) && filtering_version.prerelease == version.prerelease
        end
        return version_hash[filtered.keys.max]
      else
        return version_hash[filtering_version]
      end
    end

    # If we've gotten this far, we're either just interested in
    # variations on a specific release, or the latest of all releases
    # (depending on various combinations of prerelease and nightly
    # status)
    filtered = version_hash.select do |version, url_path|

      # If we're given a version to filter by, then we're only
      # interested in other versions that share the same major, minor,
      # and patch versions.
      #
      # If we weren't given a version to filter by, then we don't
      # care, and we'll take everything
      in_release_tree = filtering_version ? filtering_version.in_same_release_tree(version) : true

      (if prerelease && use_nightlies
         version.prerelease? && version.nightly?
       elsif !prerelease && use_nightlies
         !version.prerelease? && version.nightly?
       elsif prerelease && !use_nightlies
         version.prerelease? && !version.nightly?
       elsif !prerelease && !use_nightlies
         version.release?
       end) && in_release_tree
    end

    # return the best match (i.e., the most recent thing, subject to
    # our filtering parameters)
    filtered[filtered.keys.max]
  end


  # Take the input architecture, and an optional version (latest is
  # default), and redirect to an appropriate build. This is called for
  # both /download
  def handle_download(name, build_hash)
    platform         = params['p']
    platform_version = params['pv']
    machine          = params['m']

    chef_version     = params['v']
    prerelease       = params['prerelease'] == "true"
    use_nightlies    = params['nightlies'] == "true"

    error_msg = "No #{name} installer for platform #{platform}, platform_version #{platform_version}, machine #{machine}"

    if !build_hash[platform] || !build_hash[platform][platform_version] || !build_hash[platform][platform_version][machine]
      raise InvalidDownloadPath, error_msg
    end

    raw_versions_available = build_hash[platform][platform_version][machine]

    semvers_available = raw_versions_available.reduce({}) do |acc, kv|
      version_string, url_path = kv
      version = Opscode::SemVer.new(version_string)
      acc[version] = url_path
      acc
    end

    package_url = filter_semvers(semvers_available, chef_version, prerelease, use_nightlies)

    unless package_url
      raise InvalidDownloadPath, error_msg
    end    

    base = "#{request.scheme}://#{settings.aws_bucket}.s3.amazonaws.com"
    redirect base + package_url
  end
end
