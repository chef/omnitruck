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
pkg_name=omnitruck
pkg_origin=chef-es
pkg_version=undefined
pkg_shasum=undefined
pkg_upstream_url="https://github.com/chef/omnitruck"
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_description="API to query available versions of Omnibus artifacts"
pkg_license=('Apache-2.0')

pkg_build_deps=(
  core/coreutils
  core/gcc
  core/make
  core/git
)

pkg_deps=(
  core/ruby/$(cat $PLAN_CONTEXT/../../.ruby-version)
  core/bundler
  core/cacerts
  core/glibc
  core/coreutils
)

pkg_svc_user="hab"
pkg_svc_group=$pkg_svc_user

pkg_lib_dirs=(lib)
pkg_exports=(
  [port]=port
)

pkg_expose=(port)

do_verify() {
  pkg_version=`git rev-list master --count`
  pkg_dirname="${pkg_name}-${pkg_version}"
  pkg_prefix="$HAB_PKG_PATH/${pkg_origin}/${pkg_name}/${pkg_version}/${pkg_release}"
  pkg_artifact="$HAB_CACHE_ARTIFACT_PATH/${pkg_origin}-${pkg_name}-${pkg_version}-${pkg_release}-${pkg_target}.${_artifact_ext}"
}

do_prepare() {
  pushd $PLAN_CONTEXT/../.. > /dev/null
  mkdir -pv "$HAB_CACHE_SRC_PATH/${pkg_name}-${pkg_version}"
  tar -cvf - --exclude=.[a-z]* --exclude=results --exclude=cookbooks --exclude=spec --exclude=habitat . | (cd $HAB_CACHE_SRC_PATH/${pkg_name}-${pkg_version} && tar -xf - .)
  popd > /dev/null
}

do_build() {
  pushd "$HAB_CACHE_SRC_PATH/${pkg_name}-${pkg_version}" > /dev/null

  # shellcheck disable=SC2153
  export CPPFLAGS="${CPPFLAGS} ${CFLAGS}"

  # shellcheck disable=SC2155
  local _bundler_dir=$(pkg_path_for bundler)

  # shellcheck disable=SC2154
  export GEM_HOME=${pkg_prefix}/vendor/bundle
  export GEM_PATH=${_bundler_dir}:${GEM_HOME}

  bundle install --jobs 2 --retry 5 --deployment --binstubs

  popd > /dev/null
}

do_install() {
  pushd "$HAB_CACHE_SRC_PATH/${pkg_name}-${pkg_version}" > /dev/null

  cp -R . "${pkg_prefix}/static"
  # sometimes gem authors commit and release files that aren't "other" readable.
  find ${pkg_prefix}/static -not -perm -o+r -exec chmod o+r {} \;

  for binstub in ${pkg_prefix}/static/bin/*; do
    build_line "Setting shebang for ${binstub} to 'ruby'"
    [[ -f $binstub ]] && sed -e "s#/usr/bin/env ruby#$(pkg_path_for ruby)/bin/ruby#" -i "$binstub"
  done

  fix_interpreter ${pkg_prefix}/static/poller core/coreutils bin/env
  popd > /dev/null
}

do_download() {
  return 0
}

do_unpack() {
  return 0
}
