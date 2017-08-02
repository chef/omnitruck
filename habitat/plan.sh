# omnitruck plan is located in /habitat root because of ruby scaffolding.
# Scaffolding looks for a relative Gemfile
#
pkg_name=omnitruck-app
pkg_origin=chef-es
pkg_version=0.1.0
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_license=('Apache-2.0')
pkg_deps=(
  core/coreutils
)
# This is set to force the source path to the root level during automate builds
# You must build plan from the root dir with command `build habitat`
# Recommended to execute `scripts/hab-it`
SRC_PATH="../"

pkg_scaffolding=core/scaffolding-ruby
scaffolding_ruby_pkg=core/ruby/$(cat "$PLAN_CONTEXT/../.ruby-version")

do_install() {
  do_default_install
  fix_interpreter "$pkg_prefix/app/poller" core/coreutils bin/env
}
