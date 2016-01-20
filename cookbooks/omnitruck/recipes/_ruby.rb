# set the brightbox-ruby package version
# NOTE: ensure this is set to the same version as
# what is set in the default recipe in the build cookbook
# to ensure the vendored bundle is built by and consumed
# by the same ruby version.
node.override['brightbox-ruby']['version'] = "2.2"

include_recipe 'brightbox-ruby'
