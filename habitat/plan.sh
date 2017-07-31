# omnitruck plan is located in /habitat root because of ruby scaffolding.
# Scaffolding looks for a relative Gemfile
#
pkg_name=omnitruck
pkg_origin=chef-es
# Previous versions of omnitruck used an automatic version assignment for the
# habitat pkg_version value which was base on the git commit count. Since we
# use `sort --version-sort -r` in plan-build to determine the latest version of
# any given package we need to set a value which sorts higher than the 950+
# commits which are in the repo at the time of this change. Since we have 
# additional hab services which depend on the omnitruck hab package, they will
# uninintentionally install a version which is not the latest unless we use a
# version which starts with 1000.x.x or greater.
pkg_version=1000.0.0
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_license=('Apache-2.0')
# This is set to force the source path to the root level during automate builds
# You must build plan from the root dir with command `build habitat`
# Recommended to execute `scripts/hab-it`
SRC_PATH="../"

pkg_scaffolding=core/scaffolding-ruby
scaffolding_ruby_pkg=core/ruby/$(cat "$PLAN_CONTEXT/../.ruby-version")
