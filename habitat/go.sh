#!/bin/bash -e

HAB_ORIGIN=${HAB_ORIGIN:-"$USER"}
PACKAGE_DIRS=($(find . -name plan.sh -exec dirname '{}' \; | sort))

for pkg in "${PACKAGE_DIRS[@]}"; do
  unset pkg_name
  echo "******************* Building ${pkg}"
  #hab pkg build "$pkg"
  build "$pkg"
  #eval $(grep pkg_name $pkg/plan.sh)
  #echo "******************* Installing ${pkg}"
  #hab pkg install $(ls results/${HAB_ORIGIN}-${pkg_name}-* | tail -n 1)
done


hab sup load $HAB_ORIGIN/omnitruck --force
hab sup load $HAB_ORIGIN/omnitruck-web-proxy --bind app:omnitruck-web.default --force
hab sup load $HAB_ORIGIN/omnitruck-poller --force
hab sup load $HAB_ORIGIN/omnitruck-web --bind app:omnitruck.default --force
hab sup run
