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


  # Helper to turn a chef version into an array for comparison with other versions
  def version_to_array(v, rex)
    v_arr = v.match(rex)[1..4]
    v_arr[3] ||= 0
    v_arr.map! {|i| i.to_i}
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
    chef_version     = params['v']
    platform         = params['p']
    platform_version = params['pv']
    machine          = params['m']

    directory = JSON.parse(File.read(settings.build_list))
    package_url = begin
                    versions_for_platform = directory[platform][platform_version][machine]
                    # Rubygems considers any version with an alpha character to be a non-stable release
                    # Thus we will exclude these builds unless the user explicitly chooses them
                    if chef_version and ( chef_version.include?("-") or chef_version.match(/[[:alpha:]]/) )
                      versions_for_platform[chef_version]
                    else
                      version_arrays =[]
                      # Turn the versions into arrays for comparison i.e. "10.12.0-4" => [10,12,0,4]
                      rex = /(\d+).(\d+).(\d+)-?(\d+)?/
                      version_arrays = versions_for_platform.keys.map do |v|
                        # exclude versions such as x.y.z.beta.0 and x.y.z.rc.1
                        next if v.match(/[[:alpha:]]/)
                        version_to_array(v, rex)
                      end
                      # Remove nils left behind by prior match
                      version_arrays.delete_if { |v| v == nil }
                      # Turn the chef_version param into an array
                      unless chef_version.nil? || chef_version == ""
                        c_v_array = version_to_array(chef_version, rex)
                      end
                      if chef_version.nil? || chef_version == ""
                        c_v_array = version_arrays.max
                      end
                      # Find all of the iterations of the version matching the first three parts of chef_version
                      matching_versions = version_arrays.find_all {|v| v[0..2] == c_v_array[0..2]}
                      # Grabs the max iteration number
                      c_v_array = matching_versions.max_by {|v| v[-1]}
                      # turn chef_version from an array back into a string
                      chef_version_final = c_v_array[0..2].join('.')
                      chef_version_final += "-#{c_v_array[-1]}" unless c_v_array[-1] == 0
                      versions_for_platform[chef_version_final]
                    end
                  rescue
                    # package_url gets set to nil, error gets raised
                    nil
                  end
    unless package_url
      error_message = "No chef-client #{chef_version_final} installer for #{platform} #{platform_version} #{machine}"
      raise InvalidDownloadPath, error_message
    end
    base = "#{request.scheme}://#{settings.aws_bucket}.s3.amazonaws.com"
    redirect base + package_url
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
  get '/human_readable_list' do
    directory = JSON.parse(File.read(settings.human_readable_list))
    JSON.pretty_generate(directory)
  end

  #
  # Status endpoint used by nagios to check on the app.
  #
  get '/_status' do
    directory = JSON.parse(File.read(settings.build_list))
    status = { :timestamp => directory['run_data']['timestamp'] }
    JSON.pretty_generate(status)
  end

end
