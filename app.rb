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

class Omnitruck < Sinatra::Base
  register Sinatra::ConfigFile

  config_file './config/config.yml'

  class InvalidDownloadPath < StandardError; end
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

  get '/download' do
    pass unless project_allowed('chef')
    handle_download('chef', JSON.parse(File.read(build_list_v1('chef'))))
  end

  get '/download-:project' do
    pass unless project_allowed(project)
    handle_download(project, JSON.parse(File.read(build_list_v1(project))))
  end

  get '/metadata' do
    package_info = get_package_info('chef', JSON.parse(File.read(build_list_v2('chef'))))
    package_info["url"] = convert_relpath_to_url(package_info["relpath"])
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      JSON.pretty_generate(package_info)
    end
  end

  get '/metadata-:project' do
    pass unless project_allowed(project)

    package_info = get_package_info(project, JSON.parse(File.read(build_list_v2(project))))
    package_info["url"] = convert_relpath_to_url(package_info["relpath"])
    if request.accept? 'text/plain'
      parse_plain_text(package_info)
    else
      JSON.pretty_generate(package_info)
    end
  end

  # TODO: Replace with redirect
  get '/full_client_list' do
    content_type :json
    directory = JSON.parse(File.read(build_list_v1('chef')))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end


  # TODO: Replace with redirect
  get '/full_list' do
    content_type :json
    directory = JSON.parse(File.read(build_list_v1('chef')))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end

  get "/full_:project\\_list" do
    pass unless project_allowed(project)
    content_type :json
    directory = JSON.parse(File.read(build_list_v1(project)))
    directory.delete('run_data')
    JSON.pretty_generate(directory)
  end

  # TODO: Replace with redirect
  get '/chef_server_platform_names' do
    platform_names_path = platform_names('server')
    if File.exists?(platform_names_path)
      directory = JSON.parse(File.read(platform_names_path))
      JSON.pretty_generate(directory)
    else
      status 404
      env['sinatra.error']
      'File not found on server.'
    end
  end

  get '/:project\\_platform_names' do
    pass unless project_allowed(project)
    platform_names_path = platform_names(params[:project])
    if File.exists?(platform_names_path)
      directory = JSON.parse(File.read(platform_names_path))
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
    directory = JSON.parse(File.read(build_list_v1('chef')))
    status = { :timestamp => directory['run_data']['timestamp'] }
    JSON.pretty_generate(status)
  end

  # ---
  # HELPER METHODS
  # ---

  def project_allowed(project_name)
    settings.projects.include? project_name
  end

  def build_list_v1(project_name)
    File.join(metadata_dir, "build_#{project_name}_list_v1.json")
  end

  def build_list_v2(project_name)
    File.join(metadata_dir, "build_#{project_name}_list_v2.json")
  end

  def platform_names(project_name)
    File.join(metadata_dir, "#{project_name}_platform_names.json")
  end

  def metadata_dir
    if settings.respond_to?(:metadata_dir)
      settings.metadata_dir
    else
      './'
    end
  end

  def project
    params['project'].gsub('-', '_')
  end



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
  def janky_workaround_for_processing_all_our_different_version_strings(version_string)
    v = Opscode::Version.parse(version_string)

    if v.nil?
      raise InvalidDownloadPath, "Unsupported version format '#{version_string}'"
    else
      return v
    end
  end

  # Convert the given +chef_version+ parameter string into a
  # +Opscode::Version+ object.  Returns +nil+ if +chef_version+ is
  # either +nil+, +blank+ or the String +"latest"+.
  def resolve_version(chef_version)
    if chef_version.nil? || chef_version.empty? || chef_version.to_s == "latest"
      nil
    else
      janky_workaround_for_processing_all_our_different_version_strings(chef_version)
    end
  end

  # Take the input architecture, and an optional version (latest is
  # default), and returns the bottom level of the hash, if v1, this is simply the
  # s3 url (aka relpath), if v2, it is a hash of the relpath and checksums.
  def get_package_info(name, build_hash)
    platform         = params['p']
    platform_version = params['pv']
    machine          = params['m']

    chef_version     = params['v']
    prerelease       = params['prerelease'] == "true"
    use_nightlies    = params['nightlies'] == "true"

    error_msg = "No #{name} installer for platform #{platform}, platform_version #{platform_version}, machine #{machine}"

    chef_version = resolve_version(chef_version)

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
        version = janky_workaround_for_processing_all_our_different_version_strings(version_string) rescue nil
        acc[version] = url_path unless version.nil?
        acc
      end

      next if !pv_semvers

      semvers_available.merge!(pv_semvers)
    end

    target = Opscode::Version.find_target_version(
      semvers_available.keys,
      chef_version,
      prerelease || use_nightlies
    )

    unless target
      raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{error_msg}"
    end

    package_info = semvers_available[target]

    unless package_info
      raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{error_msg}"
    end

    package_info
  end

  def convert_relpath_to_url(relpath)
    # Ensure all pluses in package name are replaced by the URL-encoded version
    # This works around a bug in S3:
    # https://forums.aws.amazon.com/message.jspa?messageID=207700
    relpath.gsub!(/\+/, "%2B")
    base = "#{request.scheme}://#{settings.aws_packages_bucket}.s3.amazonaws.com"
    base + relpath
  end

  def handle_download(name, build_hash)
    package_url = get_package_info(name, build_hash)
    full_url = convert_relpath_to_url(package_url)
    redirect full_url
  end

  # parses package_info hash into plaintext string
  def parse_plain_text(package_info)
    full_url = convert_relpath_to_url(package_info["relpath"])
    ret = "url\t#{full_url}\nmd5\t#{package_info['md5']}\nsha256\t#{package_info['sha256']}\n"
    ret
  end
end
