#!/bin/bash
set -euo pipefail

if [[ ! -z ${CI+x} ]]; then
  mkdir -p ~/.kube
  aws --profile chef-cd s3 cp s3://chef-cd-citadel/kubernetes.chef.co.config ~/.kube/config
else
  echo "WARN: Not running in Buildkite, assuming local manual deployment"
  echo "WARN: This requires that ~/.kube/config exists with the proper content"
fi

export ENVIRONMENT=${ENVIRONMENT:-dev}
export APP=${APP}
DEBUG=${DEBUG:-false}

# This block translates the "environment" into the appropriate Habitat
# channel from which to deploy the packages
if [ "$ENVIRONMENT" == "acceptance" ]; then
  export CHANNEL=acceptance
elif [ "$ENVIRONMENT" == "production" ]; then
  export CHANNEL=stable
elif [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "test" ]; then
  export CHANNEL=unstable
else
  echo "We do not currently support deploying to $ENVIRONMENT"
  exit 1
fi

# We need the HAB_AUTH_TOKEN set (via Buildkite pipeline) for private packages
get_image_tag() {
  results=$(curl --silent -H "Authorization: Bearer $HAB_AUTH_TOKEN" https://willem.habitat.sh/v1/depot/channels/chefops/${CHANNEL}/pkgs/${APP}/latest | jq '.ident')
  pkg_version=$(echo "$results" | jq -r .version)
  pkg_release=$(echo "$results" | jq -r .release)
  echo "${pkg_version}-${pkg_release}"
}

# Retrieves the ELB's public DNS name
get_elb_hostname() {
  kubectl get services ${APP}-${ENVIRONMENT} --namespace=${APP} -o json 2>/dev/null | \
    jq '.status.loadBalancer.ingress[].hostname' -r
}

# The ELB isn't ready until the hostname is set, so wait until it's ready
wait_for_elb() {
  attempts=0
  max_attempts=10
  elb_host=""
  while [[ $attempts -lt $max_attempts ]]; do
    elb_host=$(get_elb_hostname || echo)

    if [[ ! -n $elb_host ]]; then
      echo "Did not find ELB yet... sleeping 5s"
      attempts=$[$attempts + 1]
      sleep 5
    else
      echo "Found ELB: $elb_host"
      break
    fi
  done
}

# Used for debugging on a local workstation
if [[ $DEBUG == "true" ]]; then
  echo "--- DEBUG: Environment"
  echo "Application: ${APP}"
  echo "Channel: ${CHANNEL}"
  echo "Environment: ${ENVIRONMENT}"
fi

echo "--- Applying kubernetes configuration for ${ENVIRONMENT} to cluster"
IMAGE_TAG=$(get_image_tag) erb -T- kubernetes/deployment.yml | kubectl apply -f -

if [[ `grep -c "^kind: Service$" kubernetes/deployment.yml` -gt 0 ]]; then
  echo "+++ Waiting for Load Balancer..."
  wait_for_elb
fi
