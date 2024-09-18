#  --
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2017 Chef Software, Inc.
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
require 'sinatra/cors'
require 'sinatra/param'
require 'json'
require 'pp'

require 'logger'
require 'statsd'
require 'trashed'
require 'trashed/reporter'

require 'chef/version'
require 'platform_dsl'
require 'dist'
require 'mixlib/versioning'
require 'mixlib/install'

require 'chef/cache'
require 'chef/version_resolver'

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile
  register Sinatra::Cors

  helpers Sinatra::Param

  config_file ENV['OMNITRUCK_YAML'] || './config/config.yml'

  class InvalidChannelName < StandardError; end

  configure do
    # CORS support
    set :allow_origin, "*"
    set :allow_methods, "GET"
    set :allow_headers, "content-type,if-modified-since"

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
    '/full_client_list' => '/chef/packages',
    '/full_list' => '/chef/packages',
    '/full_server_list' => '/chef-server/packages',
    '/chef/full_client_list' => '/chef/packages',
    '/chef/full_list' => '/chef/packages',
    '/chef/full_server_list' => '/chef-server/packages',
    '/metadata-chefdk' => '/chefdk/metadata',
    '/download-chefdk' => '/chefdk/download',
    '/chef_platform_names' => '/platforms',
    '/chef_server_platform_names' => '/platforms',
    '/chef/chef_platform_names' => '/platforms',
    '/chef/chef_server_platform_names' => '/platforms',
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

  client = OmnitruckDist::CLIENT_NAME

  get "/#{client}/install.msi" do
    # default to 32-bit architecture for now
    redirect to("/stable/#{client}/download?p=windows&pv=2008r2&m=i386")
  end

  get '/install.msi' do
    # default to 32-bit architecture for now
    redirect to("/stable/#{client}/download?p=windows&pv=2008r2&m=i386")
  end

  get "/full_:project\\_list" do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project}/packages")
    [status, headers, body]
  end

  get '/:project\\_platform_names' do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project}/platforms")
    [status, headers, body]
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/versions\/?$/ do
    pass unless project_allowed(project)
    redirect_url = "/#{channel}/#{project}/packages"
    redirect_url += "?v=#{params['v']}" unless params['v'].nil?
    redirect redirect_url, 302
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/platforms/ do
    pass unless project_allowed(project)
    redirect '/platforms', 302
  end
  #########################################################################
  # END LEGACY REDIRECTS
  #########################################################################

  #
  # Serve up the installer script
  #
  get /install\.(?<extension>[\w]+)/ do
    param :extension, String, required: true

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
    param :channel, String, default: 'stable'
    param :project, String, in: Chef::Cache::KNOWN_PROJECTS, required: true
    param :p,       String, required: true
    param :pv,      String, required: true
    param :m,       String, required: true
  
    # Get package information
    package_info = get_package_info
  
    # Grab org url
    original_url = package_info["url"]
  
    # Debug output of original URL
    # puts "Debug Info - Original URL: #{original_url}"
  
    # amazon 2 rewrite nonsense
    if original_url.include?("/amazon/2023/") && params[:pv] == "2"
      # Rewrite the URL for Amazon Linux 2
      rewritten_url = original_url
                       .gsub(/\/amazon\/2023\//, "/amazon/2/")
                       .gsub(/.amazon2023/, ".amazon2")
  
      # uncomment for debug
      # puts "Debug Info - Rewritten URL: #{rewritten_url}"
  
      redirect rewritten_url
    else
      # Redirect to the original URL if no rewrite needed
      redirect original_url
    end
  end

  # another dirty hack to handle amazon 2, and how the commercial downloads api handles / uses the metadata. All this needs to be rewritten to include amazon2 as a valid platform. 
  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/metadata\/?$/ do
    # Legacy params which affect the default channel
    param :prerelease, Boolean
    param :nightlies,  Boolean
    param :channel, String, default: lambda {
      if params['prerelease'] || params['nightlies']
        'current'
      else
        'stable'
      end
    }
    param :project, String, in: Chef::Cache::KNOWN_PROJECTS, required: true
    param :p,       String, required: true
    param :pv,      String, required: true
    param :m,       String, required: true
    # Get package information
    package_info = get_package_info
    # Original URL from package info
    original_url = package_info["url"]
    # Check if the URL needs to be rewritten for Amazon Linux 2
    if original_url.include?("/amazon/2023/") && params[:pv] == "2"
      # Rewrite the URL for Amazon Linux 2
      rewritten_url = original_url
                       .gsub(/\/amazon\/2023\//, "/amazon/2/")
                       .gsub(/-amazon2023/, "-amazon2")
                       .gsub(/.amazon2023/, ".amazon2")
      # Update the package_info with the rewritten URL
      package_info["url"] = rewritten_url
      # Debug output of the rewritten URL
      puts "Debug Info - Rewritten Metadata URL: #{rewritten_url}"
    end
    # Respond with the updated package stuff
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      content_type :json
      JSON.pretty_generate(package_info)
    end
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/packages\/?$/ do
    param :channel, String, default: 'stable'
    param :project, String, in: Chef::Cache::KNOWN_PROJECTS, required: true
    param :flatten, Boolean

    content_type :json

    package_list_info = params['flatten'] ? get_flattened_package_list : get_package_list

    JSON.pretty_generate(package_list_info)
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/versions\/all/ do
    param :channel, String, default: 'stable'
    param :project, String, in: Chef::Cache::KNOWN_PROJECTS, required: true

    content_type :json

    JSON.pretty_generate(available_versions)
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/versions\/latest/ do
    param :channel, String, required: true
    param :project, String, in: Chef::Cache::KNOWN_PROJECTS, required: true

    content_type :json

    JSON.pretty_generate(available_versions.last)
  end

  get /architectures/ do
    content_type :json

    JSON.pretty_generate(
      Mixlib::Install::Options::SUPPORTED_ARCHITECTURES
    )
  end

  get /platforms/ do
    content_type :json

    JSON.pretty_generate({
      "aix"       => "AIX",
      "amazon"    => "Amazon Linux",
      "el"        => "Red Hat Enterprise Linux/CentOS",
      "debian"    => "Debian GNU/Linux",
      "freebsd"   => "FreeBSD",
      "ios_xr"    => "Cisco IOS-XR",
      "mac_os_x"  => "macOS",
      "nexus"     => "Cisco NX-OS",
      "ubuntu"    => "Ubuntu Linux",
      "rocky"     => "Rocky Linux",
      "solaris2"  => "Solaris",
      "sles"      => "SUSE Linux Enterprise Server",
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
      :timestamp => cache.last_modified_for(client, 'stable')
    })
  end

  get '/_healthz' do
    # used for liveness probe - so need to return anything
    halt 204
  end

  get '/_version' do
    JSON.pretty_generate(:version => "0.1.36")
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
    @cache ||= Chef::Cache.new()
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
  # Returns the name of the channel current request is pointing to.
  #
  # @return [String]
  #   Name of the channel.
  #
  def channel
    params['channel'].gsub('/','')
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
  # Returns the available versions for a project and channel
  #
  # @return [Array]
  #   List of available version strings
  #
  def available_versions
    Mixlib::Install.available_versions(project, channel)
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
    # Set params to variables that may be modified
    current_project = project
    current_platform = params['p']
    current_platform_version = params['pv']
    current_arch = params['m']
    current_version = params['v']
    # Create VersionResolver here to take advantage of #parse_version_string
    opscode_version = Chef::VersionResolver.new(
      current_version,
      cache.manifest_for(current_project, channel),
      channel,
      current_project
    ).target_version
    # Set ceiling version if nil in place of latest version. This makes comparisons easier.
    opscode_version = Opscode::Version.parse('999.999.999') if opscode_version.nil?
    # Windows artifacts require special handling (as before)
    current_arch = if params["p"] == "windows" &&
      (current_arch.nil? || current_arch.empty? || current_arch == "i686")
                     "i386"
                   else
                     case current_arch
                     when *%w{ arm64 aarch64 }       then 'aarch64'
                     when *%w{ x86_64 amd64 x64 }    then 'x86_64'
                     when *%w{ i386 x86 i86pc i686 } then 'i386'
                     when *%w{ sparc sun4u sun4v }   then 'sparc'
                     else current_arch
                     end
                   end
    # Output current environment details for debugging purposes
    # puts "*****************"
    # puts "Current Project: #{current_project}"
    # puts "Current Platform: #{current_platform}"
    # puts "Current Platform Version: #{current_platform_version}"
    # puts "Current Architecture: #{current_arch}"
    # puts "Current Version: #{current_version}"
    # puts "*****************"
    remap_to_el = false
    # Handle SLES/SUSE as before (this section remains unchanged)
    if %{sles suse opensuse-leap}.include?(current_platform) && current_arch != "s390x"
      current_platform = 'sles'
      native_sles_project_version = OmnitruckDist::SLES_PROJECT_VERSIONS
      sles_project_version = native_sles_project_version[current_project]
      remap_to_el = true if sles_project_version.nil? || opscode_version < Opscode::Version.parse(sles_project_version)
    end
    # Amazon-specific logic, this is so dirty, needs cleaning. 
    if current_platform == "amazon" && current_platform_version == "2"
      product_version_threshold = Opscode::Version.parse("15.10.12")
      puts "Requested product version: #{opscode_version}"
      if opscode_version >= product_version_threshold
        puts "Requested version is >= 15.10.12. Keeping platform as Amazon with version 2."
        current_platform = "amazon"
        current_platform_version = "2"
        remap_to_el = false  # Ensure remap_to_el is disabled for Amazon Linux 2 and versions >= 15.10.12
      else
        puts "Requested version is < 15.10.12. Remapping to EL."
        remap_to_el = true
      end
    end
    # Only remap to EL if remap_to_el is true, and it isn't Amazon Linux 2 with version >= 15.10.12
    if remap_to_el
      current_platform_version = if current_platform == "amazon" && current_platform_version == "2"
                                   "7"
                                 else
                                   current_platform_version.to_f <= 11 ? "5" : "6"
                                 end
      current_platform = "el"
                                end
    # Handle automate/delivery based on version
    if %w{automate delivery}.include?(project)
      current_project = opscode_version < Opscode::Version.parse('0.7.0') ? 'delivery' : 'automate'
    end
    # Return the package info using the updated current values
    Chef::VersionResolver.new(
      current_version,
      cache.manifest_for(current_project, channel),
      channel,
      current_project
    ).package_info(current_platform, current_platform_version, current_arch)
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
  # Returns information about all available packages for a version in
  # a flattened form.
  #
  # @example
  # {
  #   "ubuntu": [
  #     {"platform_version": "12.04",
  #      "architecture": "i686",
  #      "url": "...",
  #        ...
  #     },
  #     {"platform_version": "12.04",
  #      "architecture": "x86_64",
  #      "url": "...",
  #        ...
  #     },
  #     ...
  #   ],
  #   "windows": [
  #     ...
  #   ]
  #   ...
  # }
  #
  # @return [Hash]
  #
  def get_flattened_package_list
    get_package_list.transform_values do |v|
      v.each_with_object([]) do |(platform_version, architecture_hash), package_array|
          package_array << architecture_hash.map do |architecture, package|
              package['architecture'] = architecture
              package['platform_version'] = platform_version
              package
          end
      end.flatten
    end
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