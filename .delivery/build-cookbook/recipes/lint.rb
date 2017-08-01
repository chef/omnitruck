################################################################################
# Welcome to the lint phase
#
# This recipe is run as the delivery user
################################################################################

return if union_or_rehearsal?

# Run lint against the cookbooks
include_recipe 'delivery-truck::lint'
include_recipe 'habitat-build::lint'
