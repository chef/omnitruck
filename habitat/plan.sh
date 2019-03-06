# omnitruck plan is located in /habitat root because of ruby scaffolding.
# Scaffolding looks for a relative Gemfile
pkg_name=omnitruck
pkg_origin=chefops
pkg_version=0.1.0
pkg_maintainer="Chef Operations <ops@chef.io>"
pkg_license=('Apache-2.0')
pkg_deps=(
  core/coreutils
)
pkg_build_deps=(
  core/make
  core/gcc
  core/tar
)

pkg_scaffolding=core/scaffolding-ruby
scaffolding_ruby_pkg=core/ruby24/$(cat "$SRC_PATH/.ruby-version")

declare -A scaffolding_env
scaffolding_env[OMNITRUCK_YAML]="/hab/svc/$pkg_name/config/config.yml"

do_install() {
  do_default_install
}
