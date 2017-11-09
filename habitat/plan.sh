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

pkg_scaffolding=core/scaffolding-ruby
scaffolding_ruby_pkg=core/ruby/$(cat "$SRC_PATH/.ruby-version")

do_install() {
  do_default_install
  fix_interpreter "$pkg_prefix/app/poller" core/coreutils bin/env
}