require 'sinatra'

#
# serve up the installer script
#
get '/install.sh' do
  
end

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
  
end
