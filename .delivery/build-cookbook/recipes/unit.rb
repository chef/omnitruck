################################################################################
# Welcome to the unit phase
#
# This phase is run as the delivery user
################################################################################

secrets = get_project_secrets

# This resource queries the Github API to determine "completeness" based on
# the Github Status API. It _is_ possible that if you push too many patchsets
# too quickly, you _could_ end up with a queue backup. However, since all
# patchsets are querying the same endpoint, they will eventually clean themselves
# out. You won't have to wait for each patchset to timeout.
github_pull_request_status "chef/#{workflow_change_project}" do
  api_token secrets['github']['chef-delivery']
  git_ref workflow_stage == 'verify' ? workflow_change_github_branch : workflow_change_merge_sha
  action :wait_for_success_or_failure
end
