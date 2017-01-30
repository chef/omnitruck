#  --
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'pp'

require 'logger'
require 'statsd'
require 'trashed'
require 'trashed/reporter'

require 'chef/version'
require 'platform_dsl'
require 'mixlib/versioning'
require 'mixlib/install'

require 'chef/cache'
require 'chef/version_resolver'

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  class InvalidChannelName < StandardError; end

  configure do
    set :raise_errors, false
    set :show_exceptions, false
    enable :logging

    set :logging, nil
    logger = Logger.new STDOUT
    logger.level = Logger::INFO
    logger.datetime_format = '%a %d-%m-%Y %H%M '
    set :logging, logger

    reporter = Trashed::Reporter.new
    reporter.logger = logger
    reporter.statsd = Statsd.new('localhost', 8125)
    use Trashed::Rack, reporter
  end

  configure :development, :test do
    set :raise_errors, true  # needed to get accurate backtraces out of rspec
  end

  #########################################################################
  # BEGIN LEGACY REDIRECTS
  #
  # These routes existed at a time when Omnitruck did not support 1..n
  # projects. Any new applications should use the project-based variant
  # which each of these internally redirect to.
  #
  #########################################################################

  {
    '/download' => '/chef/download',
    '/metadata' => '/chef/metadata',
    '/download-server' => '/chef-server/download',
    '/metadata-server' => '/chef-server/metadata',
    '/full_client_list' => '/chef/versions',
    '/full_list' => '/chef/versions',
    '/full_server_list' => '/chef-server/versions',
    '/chef/full_client_list' => '/chef/versions',
    '/chef/full_list' => '/chef/versions',
    '/chef/full_server_list' => '/chef-server/versions',
    '/metadata-chefdk' => '/chefdk/metadata',
    '/download-chefdk' => '/chefdk/download',
    '/chef_platform_names' => '/chef/platforms',
    '/chef_server_platform_names' => '/chef-server/platforms',
    '/chef/chef_platform_names' => '/chef/platforms',
    '/chef/chef_server_platform_names' => '/chef-server/platforms',
    '/chef/metadata-chefdk' => '/chefdk/metadata',
    '/chef/download-chefdk' => '/chefdk/download',
    '/chef/metadata-container' => '/container/metadata',
    '/chef/download-container' => '/container/download',
    '/chef/metadata-angrychef' => '/angrychef/metadata',
    '/chef/download-angrychef' => '/angrychef/download',
    '/chef/download-server' => '/chef-server/download',
    '/chef/metadata-server' => '/chef-server/metadata',
  }.each do |(legacy_endpoint, endpoint)|
    get(legacy_endpoint) do
      status, headers, body = call env.merge("PATH_INFO" => endpoint)
      [status, headers, body]
    end
  end

  get '/chef/install.msi' do
    # default to 32-bit architecture for now
    redirect to('/stable/chef/download?p=windows&pv=2008r2&m=i386')
  end

  get '/install.msi' do
    # default to 32-bit architecture for now
    redirect to('/stable/chef/download?p=windows&pv=2008r2&m=i386')
  end

  get "/full_:project\\_list" do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project}/versions")
    [status, headers, body]
  end

  get '/:project\\_platform_names' do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project}/platforms")
    [status, headers, body]
  end

  #########################################################################
  # END LEGACY REDIRECTS
  #########################################################################

  #
  # Serve up the installer script
  #
  get /install\.(?<extension>[\w]+)/ do
    case params['extension']
    when 'sh'
      content_type :sh
      prepare_install_sh
    when 'ps1'
      content_type :txt
      prepare_install_ps1
    else
      halt 404
    end
  end

  #
  # Handling specific exceptions raised
  #
  [
    Chef::VersionResolver::InvalidDownloadPath,
    Chef::VersionResolver::InvalidPlatform,
    Chef::Cache::MissingManifestFile,
    InvalidChannelName
  ].each do |exception_class|
    error exception_class do
      status 404
      env['sinatra.error']
    end
  end

  #########################################################################
  # Endpoints
  #########################################################################

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/download\/?$/ do
    pass unless project_allowed(project)

    package_info = get_package_info
    redirect package_info["url"]
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/metadata\/?$/ do
    pass unless project_allowed(project)

    package_info = get_package_info
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      JSON.pretty_generate(package_info)
    end
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/versions\/?$/ do
    pass unless project_allowed(project)
    content_type :json

    package_list_info = get_package_list
    JSON.pretty_generate(package_list_info)
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/platforms\/?$/ do
    pass unless project_allowed(project)

    # Historically this endpoint was being used by chef-web-downloads to
    # extend the platform keys with a human friendly versions.
    # Now that this functionality is not needed anymore we can deprecate this
    # endpoint. However in order not to break others who might be calling into
    # this we return our full set of platform key to user friendly platform
    # name mappings.
    JSON.pretty_generate({
      "aix"       => "AIX",
      "el"        => "Enterprise Linux",
      "debian"    => "Debian",
      "freebsd"   => "FreeBSD",
      "ios_xr"    => "Cisco IOS-XR",
      "mac_os_x"  => "OS X",
      "nexus"     => "Cisco NX-OS",
      "ubuntu"    => "Ubuntu",
      "solaris2"  => "Solaris",
      "sles"      => "SUSE Enterprise",
      "suse"      => "openSUSE",
      "windows"   => "Windows"
    })
  end

  #
  # Status endpoint used by nagios to check on the app.
  #
  get '/_status' do
    content_type :json

    JSON.pretty_generate({
      :timestamp => cache.last_modified_for('chef', 'stable')
    })
  end

  get '/products' do
    content_type :json

    JSON.pretty_generate(Chef::Cache::KNOWN_PROJECTS)
  end

  #########################################################################
  # Helper Methods
  #########################################################################

  #
  # Returns the instance of Chef::Cache that app is using
  #
  def cache
    @cache ||= Chef::Cache.new(metadata_dir)
  end

  #
  # Returns if the given project is known by the app.
  #
  # @parameter [String] project
  #   Name of the project.
  #
  # @return [Boolean]
  #   true if the project is known, false otherwise.
  #
  def project_allowed(project)
    Chef::Cache::KNOWN_PROJECTS.include? project
  end

  #
  # Returns the metadata directory being used.
  #
  # @return [String]
  #   File path to the metadata directory.
  #
  def metadata_dir
    if settings.respond_to?(:metadata_dir)
      settings.metadata_dir
    else
      './'
    end
  end

  #
  # Returns the name of the channel current request is pointing to.
  #
  # @return [String]
  #   Name of the channel.
  #
  def channel
    if params['channel']
      params['channel'].gsub('/','')
    else
      if params['prerelease'] == 'true' || params['nightlies'] == 'true'
        'current'
      else
        'stable'
      end
    end
  end

  #
  # Returns the name of the project current request is pointing to.
  #
  # @return [String]
  #   Name of the project.
  #
  def project
    params['project'].gsub('_', '-')
  end

  #
  # Returns the information for a single package in the form of a Hash.
  #
  # @example {
  #   url:      "",
  #   sha1:     "",
  #   sha256:   "",
  #   version:  ""
  # }
  #
  # @return [Hash]
  #
  def get_package_info
    # Windows artifacts require special handling
    # 1) If no architecture is provided we default to i386
    # 2) Internally we always use i386 to represent 32-bit artifacts, not i686
    m = if params["p"] == "windows" && (params["m"].nil? || params["m"].empty? || params["m"] == "i686")
          "i386"
        else
          # Map `uname -m` returned architectures into our internal representations
          case params["m"]
          when *%w{ x86_64 amd64 x64 }    then 'x86_64'
          when *%w{ i386 x86 i86pc i686 } then 'i386'
          when *%w{ sparc sun4u sun4v }   then 'sparc'
          else params["m"]
          end
        end

    # We need to manage automate/delivery this in this method, not #project.
    # This logic is dependent on having the version param (params['v']) set.
    # If we try to handle this in #project we have to make an assumption to
    # always return automate results when the VERSIONS api is called for delivery.
    current_project = project
    if current_project == 'automate' || current_project == 'delivery'
      # default delivery as automate
      current_project = 'automate' if current_project == 'delivery'
      if params['v']
        current_project = 'delivery' if Mixlib::Versioning.parse(params['v']) < Mixlib::Versioning.parse('0.7.0')
      end
    end

    Chef::VersionResolver.new(
      params['v'], cache.manifest_for(current_project, channel), channel, current_project
    ).package_info(params['p'], params['pv'], m)
  end

  #
  # Returns information about all available packages for a version.
  # version is either provided or calculated from the supported parameters.
  #
  # @example
  # {
  #   "ubuntu": {
  #     "12.04": {
  #       "i686": {
  #         "url": "...",
  #         ...
  #       },
  #       "x86_64": {
  #         "url": "...",
  #         ...
  #       }
  #     },
  #     "10.04": {
  #       ...
  #     }
  #   },
  #   "windows": {
  #     ...
  #   }
  #   ...
  # }
  #
  # @return [Hash]
  #
  def get_package_list
    Chef::VersionResolver.new(params['v'], cache.manifest_for(project, channel), channel, project).package_list
  end

  #
  # Parses given data into plain text.
  #
  # @parameter [Hash] data
  #
  # @return [String]
  #   Each key and value is separated by `\t` and each pair is separated
  #     by `\n`.
  #
  def parse_plain_text(data)
    output = [ ]

    data.each do |key, value|
      output << "#{key}\t#{value}"
    end

    output.join("\n")
  end

  #
  # Returns the install.sh script to be returned
  #
  # @return [String]
  #   Contents of the install.sh script
  #
  def prepare_install_sh
    Mixlib::Install.install_sh(base_url: url(settings.virtual_path).chomp('/'))
  end

  #
  # Returns the install.ps1 script to be returned
  #
  # @return [String]
  #   Contents of the install.ps1 script
  #
  def prepare_install_ps1
    Mixlib::Install.install_ps1(base_url: url(settings.virtual_path).chomp('/'))
  end
end
