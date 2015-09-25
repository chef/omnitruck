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

require 'opscode/version'
require 'platform_dsl'
require 'mixlib/versioning'

require 'chef/project'
require 'chef/project_cache'
require 'chef/channel'

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  class InvalidDownloadPath < StandardError; end
  class InvalidChannelName < StandardError; end

  configure do
    set :raise_errors, false
    set :show_exceptions, false
    enable :logging
  end

  configure :development, :test do
    set :raise_errors, true  # needed to get accurate backtraces out of rspec
  end
  #
  # serve up the installer script
  #
  get '/install.sh' do
    content_type :sh
    erb :'install.sh', {
      :layout => :'install.sh',
      :locals => {
        :download_url => url("#{settings.virtual_path}/metadata")
      }
    }
  end

  get '/install.ps1' do
    content_type :txt
    erb :'install.ps1', {
      :layout => :'install.ps1',
      :locals => {
        :download_url => url("#{settings.virtual_path}/metadata")
      }
    }
  end

  error InvalidDownloadPath do
    status 404
    env['sinatra.error']
  end

  error InvalidChannelName do
    status 404
    env['sinatra.error']
  end

  get /(?<channel>\/[\w]+)?\/download-(?<project>[\w-]+)/ do
    pass unless project_allowed(project)

    package_info = get_package_info(project, JSON.parse(File.read(project.build_list_path)))
    full_url = convert_relpath_to_url(package_info["relpath"])
    redirect full_url
  end

  get /(?<channel>\/[\w]+)?\/metadata-(?<project>[\w-]+)/ do
    pass unless project_allowed(project)

    package_info = get_package_info(project, JSON.parse(File.read(project.build_list_path)))
    package_info["url"] = convert_relpath_to_url(package_info["relpath"])
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      JSON.pretty_generate(package_info)
    end
  end

  get /(?<channel>\/[\w]+)?\/full-(?<project>[\w-]+)-list/ do
    pass unless project_allowed(project)
    content_type :json
    directory = JSON.parse(File.read(project.build_list_path))
    directory.delete('run_data')
    extract_build_list!(directory)
    JSON.pretty_generate(directory)
  end

  get /(?<channel>\/[\w]+)?\/(?<project>[\w-]+)-platform-names/ do
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

  #########################################################################
  # BEGIN LEGACY REDIRECTS
  #
  # These routes existed at a time when Omnitruck did not support 1..n
  # projects. Any new applications should use the project-based variant
  # which each of these internally redirect to.
  #
  #########################################################################

  {
    '/download' => '/download-chef',
    '/metadata' => '/metadata-chef',
    '/download-server' => '/download-chef-server',
    '/metadata-server' => '/metadata-chef-server',
    '/full_client_list' => '/full-chef-list',
    '/full_list' => '/full-chef-list',
    '/full_server_list' => '/full-chef-server-list'
  }.each do |(legacy_endpoint, endpoint)|
    get(legacy_endpoint) do
      status, headers, body = call env.merge("PATH_INFO" => endpoint)
      [status, headers, body]
    end
  end

  get "/full_:project\\_list" do
    status, headers, body = call env.merge("PATH_INFO" => "/full-#{project.name}-list")
    [status, headers, body]
  end

  get '/:project\\_platform_names' do
    status, headers, body = call env.merge("PATH_INFO" => "/#{project.name}-platform-names")
    [status, headers, body]
  end

  #########################################################################
  # END LEGACY REDIRECTS
  #########################################################################

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

  def parse_version_string(version_string)
    v = Opscode::Version.parse(version_string)

    if v.nil?
      raise InvalidDownloadPath, "Unsupported version format '#{version_string}'"
    else
      return v
    end
  end

  def extract_build_list!(json)
    # nested loops, but much easier than writing a generic DFS solution or something
    json.each do |platform, platform_value|
      next if platform.to_s == "run_data"
      platform_value.each_value do |platform_version_value|
        platform_version_value.each_value do |architecture_value|
          architecture_value.each do |chef_version, chef_version_value|
            architecture_value[chef_version] = chef_version_value["relpath"]
          end
        end
      end
    end
  end

  # Take the input architecture, and an optional version (latest is
  # default), and returns the bottom level of the hash, if v1, this is simply the
  # s3 url (aka relpath), if v2, it is a hash of the relpath and checksums.
  def get_package_info(name, build_hash)
    platform         = params['p']
    platform_version = params['pv']
    machine          = params['m']

    project_version     = params['v']

    error_msg = "No #{name} installer for platform #{platform}, platform_version #{platform_version}, machine #{machine}"

    # Convert the given +project_version+ parameter string into a
    # +Opscode::Version+ object.  Returns +nil+ if +project_version+ is
    # either +nil+, +blank+ or the String +"latest"+.
    project_version = if project_version.nil? || project_version.empty? || project_version.to_s == "latest"
      nil
    else
      parse_version_string(project_version)
    end

    dsl = PlatformDSL.new()
    dsl.from_file("platforms.rb")
    pv = dsl.new_platform_version(platform, platform_version)

    # this maps "linuxmint" onto "ubuntu", "scientific" onto "el", etc
    remapped_platform = pv.mapped_name

    if !build_hash[remapped_platform]
      raise InvalidDownloadPath, "Cannot find any chef versions for mapped platform #{pv.mapped_name}: #{error_msg}"
    end

    distro_versions_available = build_hash[remapped_platform].keys

    # pick all distros that are <= the current distro (shipping artifacts
    # for el6 to el7 is fine, but shipping el7 to el6 is bad)
    distro_versions_available.select! {|v| dsl.new_platform_version(remapped_platform, v) <= pv }

    if distro_versions_available.length == 0
      raise InvalidDownloadPath, "Cannot find any available chef versions for this mapped platform version #{pv.mapped_name} #{pv.mapped_version}: #{error_msg}"
    end

    # walk forwards through the pv list (10.04 then 10.10, etc)
    distro_versions_available.sort! {|v1,v2| dsl.new_platform_version(remapped_platform, v1) <=> dsl.new_platform_version(remapped_platform, v2) }

    # walk through all the distro versions until we find a candidate
    package_info = nil
    pv_selected = nil

    semvers_available = {}

    distro_versions_available.each do |remapped_platform_version|
      pv_selected = remapped_platform_version

      if !remapped_platform_version || !build_hash[remapped_platform][remapped_platform_version] || !build_hash[remapped_platform][remapped_platform_version][machine]
        next
      end

      raw_versions_available = build_hash[remapped_platform][remapped_platform_version][machine]

      next if !raw_versions_available

      pv_semvers = raw_versions_available.reduce({}) do |acc, kv|
        version_string, url_path = kv
        version = parse_version_string(version_string) rescue nil
        acc[version] = url_path unless version.nil?
        acc
      end

      next if !pv_semvers

      semvers_available.merge!(pv_semvers)
    end

    target = Opscode::Version.find_target_version(
      semvers_available.keys,
      project_version,
      true,
    )

    unless target
      raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{error_msg}"
    end

    package_info = semvers_available[target]

    unless package_info
      raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{error_msg}"
    end

    if package_info.is_a?(Hash)
      # Append version to the package_info if we are returning a hash
      # In v1 this returns a url and there are some tests still exercising
      # this code path.
      package_info["version"] = target
    end

    package_info
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
end
