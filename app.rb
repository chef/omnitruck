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

require 'chef/project'
require 'chef/project_cache'
require 'chef/channel'
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
    redirect to('/stable/chef/download?p=windows&pv=2008r2&m=x86_64')
  end

  get '/install.msi' do
    redirect to('/stable/chef/download?p=windows&pv=2008r2&m=x86_64')
  end

  get "/full_:project\\_list" do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project.name}/versions")
    [status, headers, body]
  end

  get '/:project\\_platform_names' do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project.name}/platforms")
    [status, headers, body]
  end

  #########################################################################
  # END LEGACY REDIRECTS
  #########################################################################



  #
  # serve up the installer script
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

  error Chef::VersionResolver::InvalidDownloadPath do
    status 404
    env['sinatra.error']
  end

  error Chef::VersionResolver::InvalidPlatform do
    status 404
    env['sinatra.error']
  end

  error InvalidChannelName do
    status 404
    env['sinatra.error']
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/download\/?$/ do
    pass unless project_allowed(project)

    package_info = get_package_info(project, JSON.parse(File.read(project.build_list_path)))
    full_url = convert_relpath_to_url(package_info["relpath"])
    redirect full_url
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/metadata\/?$/ do
    pass unless project_allowed(project)

    package_info = get_package_info(project, JSON.parse(File.read(project.build_list_path)))
    decorate_url!(package_info)
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      JSON.pretty_generate(package_info)
    end
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/versions\/?$/ do
    pass unless project_allowed(project)
    content_type :json

    package_list_info = get_package_list(project, JSON.parse(File.read(project.build_list_path)))
    decorate_url!(package_list_info)
    JSON.pretty_generate(package_list_info)
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)\/platforms\/?$/ do
    pass unless project_allowed(project)
    if File.exists?(project.platform_names_path)
      directory = JSON.parse(File.read(project.platform_names_path))
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
    content_type :json
    status = {
      :timestamp => Chef::ProjectCache.for_project('chef', channel, metadata_dir).timestamp
    }
    JSON.pretty_generate(status)
  end

  # ---
  # HELPER METHODS
  # ---

  def project_allowed(project)
    Chef::Project::KNOWN_PROJECTS.include? project.name
  end

  def metadata_dir
    if settings.respond_to?(:metadata_dir)
      settings.metadata_dir
    else
      './'
    end
  end

  def channel
    if params['channel']
      channel_for(params['channel'].gsub('/',''))
    else
      if params['prerelease'] == 'true' || params['nightlies'] == 'true'
        channel_for('current')
      else
        channel_for('stable')
      end
    end
  end

  def channel_for(channel_name)
    unless Chef::Channel::KNOWN_CHANNELS.include?(channel_name) && settings.channels.include?(channel_name)
      raise InvalidChannelName, "Unknown channel '#{channel_name}'"
    end
    Chef::Channel.new(
        channel_name, settings.channels[channel_name]['aws_metadata_bucket'],
        settings.channels[channel_name]['aws_packages_bucket']
      )
  end

  def project
    project_name = params['project'].gsub('_', '-')
    Chef::ProjectCache.for_project(project_name, channel, metadata_dir)
  end

  def get_package_info(project, build_hash)
    # Chef Windows artifacts require special handling based on channel and architecture.
    # 1-) For stable channel we always return 32-bit artifacts
    # 2-) Internally we always use i386 to represent 32-bit artifacts, not i686
    m = if (project.name == "chef" && params["p"] == "windows") &&
             (channel.name == "stable" || params["m"] == "i686")
          "i386"
        else
          params['m']
        end

    Chef::VersionResolver.new(
      params['v'], build_hash
    ).package_info(params['p'], params['pv'], m)
  end

  def get_package_list(name, build_hash)
    Chef::VersionResolver.new(params['v'], build_hash).package_list
  end

  def decorate_url!(package_info)
    if package_info.keys.include? 'relpath'
      package_info["url"] = convert_relpath_to_url(package_info["relpath"])
    else
      package_info.each do |key, value|
        decorate_url!(value)
      end
    end
  end

  def convert_relpath_to_url(relpath)
    # Ensure all pluses in package name are replaced by the URL-encoded version
    # This works around a bug in S3:
    # https://forums.aws.amazon.com/message.jspa?messageID=207700
    relpath.gsub!(/\+/, "%2B")
    base = "#{request.scheme}://#{channel.aws_packages_bucket}.s3.amazonaws.com"
    base + relpath
  end

  # parses package_info hash into plaintext string
  def parse_plain_text(package_info)
    full_url = convert_relpath_to_url(package_info["relpath"])
    "url\t#{full_url}\nmd5\t#{package_info['md5']}\nsha256\t#{package_info['sha256']}\nversion\t#{package_info['version']}"
  end

  def prepare_install_sh
    Mixlib::Install.install_sh(base_url: url(settings.virtual_path))
  end

  def prepare_install_ps1
    Mixlib::Install.install_ps1(base_url: url(settings.virtual_path))
  end
end
