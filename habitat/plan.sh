# omnitruck plan is located in /habitat root because of ruby scaffolding.
# Scaffolding looks for a relative Gemfile
#
pkg_name=omnitruck
pkg_origin=chef-es
pkg_version="0.1.0"
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_license=('Apache-2.0')

pkg_scaffolding=core/scaffolding-ruby
scaffolding_ruby_pkg=core/ruby/$(cat "$PLAN_CONTEXT/../.ruby-version")

pkg_deps=(
  core/coreutils
)

do_install() {
  do_default_install

  fix_interpreter ${pkg_prefix}/app/poller core/coreutils bin/env
}
