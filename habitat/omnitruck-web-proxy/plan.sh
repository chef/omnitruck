#
# Copyright:: Copyright (c) 2017 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
pkg_name=omnitruck-web-proxy
pkg_origin=chef-es
pkg_version=0.1.0
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_description="Nginx HTTP Proxy for Omnitruck"
pkg_license=('Apache-2.0')

pkg_deps=(
  core/nginx
  core/curl
  $HAB_ORIGIN/omnitruck-web
)
pkg_svc_run="nginx -c ${pkg_svc_config_path}/nginx.conf"
pkg_svc_user="root"
pkg_svc_group=$pkg_svc_user

pkg_exports=(
  [port]=server.listen
)

pkg_exposes=(port)

do_build() {
  return 0
}

do_install() {
  return 0
}
