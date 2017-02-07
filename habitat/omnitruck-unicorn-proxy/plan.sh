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
pkg_name=omnitruck-unicorn-proxy
pkg_origin=chef-es
pkg_version=1.0.0
pkg_shasum=undefined
pkg_source=nosuchfile.tar.xz
pkg_upstream_url="http://nginx.org/"
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_description="Nginx HTTP Proxy for Omnitruck"
pkg_license=('Apache-2.0')

pkg_deps=(core/nginx core/curl)
pkg_svc_run="nginx -c ${pkg_svc_config_path}/nginx.conf"
pkg_svc_user="root"
pkg_svc_group=$pkg_svc_user

do_verify() {
  return 0
}

do_begin() {
  return 0
}

do_build() {
  return 0
}

do_download() {
  return 0
}

do_install() {
  return 0
}

do_prepare() {
  return 0
}

do_unpack() {
  return 0
}
