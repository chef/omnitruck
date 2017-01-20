################################################################################
# Welcome to the publish phase
#
# This is run as the delivery build user, and defers to the
# `habitat-build` cookbook to create the artifact for the omnitruck
# application that will be deployed in later stages.
#
################################################################################

include_recipe 'chef-sugar::default'
include_recipe 'delivery-truck::publish'
include_recipe 'habitat-build::publish'
