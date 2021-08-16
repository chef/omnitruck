.DEFAULT_GOAL := help

# If you want to manage your own custom Makefile targets, just add them to Makefile.local. This file is gitignored, so
# it won't get committed.
-include Makefile.local

#
# Variables
#

# Assuming running docker for mac k8s
KUBECTL_CONTEXT ?= docker-desktop

#help:	@ List available tasks on this project
help:
	@grep -h -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | sort | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#
# Manage the dev environment
#

#dev.skaffold: @ Start a new 'skaffold dev'
dev.skaffold: deps.bitnami
	skaffold dev

#deps.bitnami: @ Configure Helm with the Bitnami repository
deps.bitnami:
	helm repo add bitnami https://charts.bitnami.com/bitnami

#docker.delete-images: @ Delete omnitruck docker images
docker.delete-images:
	docker images -a | grep "$(IMAGE_REGISTRY)/omnitruck" | awk '{print $$3}' | xargs docker rmi -f

#docker.deploy-registry: @ Deploy local docker registry
docker.deploy-registry:
	@$(MAKE) --ignore-errors docker.uninstall-registry
	docker run -d -p 5000:5000 --restart=always --name registry registry:2

#docker.uninstall-registry: @ Uninstall local docker registry
docker.uninstall-registry:
	docker container stop registry && docker container rm -v registry
