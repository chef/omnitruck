require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'pp'

require 'opscode/semver'
require 'opscode/opscode_semver'

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


  # TODO: why not do a permanent redirect here instead?
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

  ######################## NOTICE ##############################################
  #
  # The following is an intentionally horrible method, both in name
  # and implementation, in the hopes that its continuing presence will
  # be a persistent goad to clean up the variety of version strings we
  # have in Omnitruck, and converge upon a single uniform scheme.
  #
  ##############################################################################

  # Handles the unification of the various versions in Omnitruck **AT
  # THE TIME OF WRITING** (late December 2012).  All the versions in
  # the 10.x line are mostly Rubygems-style versions, whereas most of
  # the ones in the 11.x line are 'git describe'-based, with more
  # recent ones transitioning to a more proper SemVer-style scheme.
  #
  # Eventually, we will converge on the +OpscodeSemVer+ style, which has
  # recently been added to our Omnibus build system.  This version is
  # SemVer compliant, but enforces Opscode-specific conventions for
  # pre-release and build specifiers.
  # 
  # Once we phase out the other versioning schemes, this method can go
  # away completely in favor of direct instantiation of an
  # +OpscodeSemVer+ object.
  #
  # Note that there is no support in this method for 12.x versions; if
  # this code is still around when Chef 12 comes out, we have larger
  # problems :)
  def janky_workaround_for_processing_all_our_different_version_strings(version_string)
    if version_string.start_with?("10.")
      begin
        Opscode::RubygemsVersion.new(version_string)
      rescue
        Opscode::GitDescribeVersion.new(version_string)
      end
    elsif version_string.start_with?("11.")
      begin
        Opscode::GitDescribeVersion.new(version_string)
      rescue
        begin
          # Note: This is the single version format we should converge upon
          Opscode::OpscodeSemVer.new(version_string)
        rescue
          Opscode::SemVer.new(version_string)
        end
      end
    else
      raise Error, "Unsupported version format #{version_string}"
    end
  end

  # Convert the given +chef_version+ parameter string into a
  # +Opscode::Version+ object.  Returns +nil+ if +chef_version+ is
  # either +nil+ or the String +"latest"+.
  def resolve_version(chef_version)
    if chef_version.nil? || chef_version == "latest"
      nil
    else
      janky_workaround_for_processing_all_our_different_version_strings(chef_version)
    end
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

    # TODO: Handle invalid chef_version strings
    chef_version = resolve_version(chef_version)

    if !build_hash[platform] || !build_hash[platform][platform_version] || !build_hash[platform][platform_version][machine]
      raise InvalidDownloadPath, error_msg
    end

    raw_versions_available = build_hash[platform][platform_version][machine]
    
    semvers_available = raw_versions_available.reduce({}) do |acc, kv|
      version_string, url_path = kv
      version = janky_workaround_for_processing_all_our_different_version_strings(version_string)
      acc[version] = url_path
      acc
    end

    target = Opscode::Version.find_target_version(semvers_available.keys,
                                                  chef_version,
                                                  prerelease, 
                                                  use_nightlies)
    
    package_url = semvers_available[target]

    unless package_url
      raise InvalidDownloadPath, error_msg
    end    

    base = "#{request.scheme}://#{settings.aws_bucket}.s3.amazonaws.com"
    redirect base + package_url
  end
end
