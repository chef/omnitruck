pkg_name=omnitruck-web
pkg_origin=chef-es
pkg_version="0.1.0"
pkg_maintainer="Chef Engineering Services <eng-services@chef.io>"
pkg_license=('Apache-2.0')

pkg_exports=(
  [tcp_socket]=unicorn.listen_port
)

pkg_exposes=(
  tcp_socket
)

pkg_binds=(
  [app]="port"
)

pkg_deps=(
  $HAB_ORIGIN/omnitruck
)

do_build() {
  return 0
}

do_install() {
  return 0
}
