.DEFAULT_GOAL := help
.PHONY: help

#
# Variables
#

# Assuming running docker for mac k8s
KUBECTL_CONTEXT ?= docker-desktop

#
# Targets
#

deploy.force-update: # @HELP Rebuild and restart all omnitruck containers
deploy.force-update:
	@$(MAKE) dobi.publish
	kubectl --context $(KUBECTL_CONTEXT) -n omnitruck rollout restart \
		deployment/omnitruck

deploy.local: # @HELP Build and deploy omnitruck's dev env
deploy.local:
	@$(MAKE) dobi.publish \
	linkerd.install \
	gloo.install \
	kube.apply-kustomize \
	kube.follow-logs

deploy.teardown: # @HELP Tear down the omnitruck's dev env
deploy.teardown: 
	@$(MAKE) --ignore-errors kube.delete-kustomize \
	linkerd.uninstall \
	gloo.uninstall

dobi.publish: # @HELP Build and publish all of omnitruck's docker images
dobi.publish:
	@$(MAKE) dobi.publish-omnitruck 

dobi.publish-omnitruck: # @HELP Build and publish omnitruck's docker image
dobi.publish-omnitruck:
	dobi publish-omnitruck
	docker tag $(IMAGE_REGISTRY)/omnitruck:$(VERSION) \
		$(IMAGE_REGISTRY)/omnitruck:local


docker.delete-images: # @HELP Delete omnitruck docker images
docker.delete-images:
	docker images -a | grep "$(IMAGE_REGISTRY)/omnitruck" | awk '{print $$3}' | xargs docker rmi -f

docker.deploy-registry: # @HELP Deploy local docker registry
docker.deploy-registry:
	@$(MAKE) --ignore-errors docker.uninstall-registry
	docker run -d -p 5000:5000 --restart=always --name registry registry:2

docker.uninstall-registry: # @HELP Uninstall local docker registry
docker.uninstall-registry:
	docker container stop registry && docker container rm -v registry

flagger.install:  # @HELP Install Flagger and its CRDs 
flagger.install:
	kubectl --context $(KUBECTL_CONTEXT) apply -k github.com/weaveworks/flagger//kustomize/linkerd

flagger.uninstall: # @HELP Uninstall Flagger and its CRDs 
flagger.uninstall:
	kubectl --context $(KUBECTL_CONTEXT) delete -k github.com/weaveworks/flagger//kustomize/linkerd

gloo.dashboard: # @HELP Open the Gloo web dashboard
gloo.dashboard:
	glooctl -n omnitruck dashboard

gloo.install: # @HELP Install the gloo gateway in the omnitruck namespace
gloo.install:
	glooctl check -n omnitruck || glooctl install gateway -n omnitruck --with-admin-console

gloo.uninstall: # @HELP Uninstall all gloo resources
gloo.uninstall:
	glooctl -n omnitruck uninstall --all

help: # @HELP Prints this message
help:
	@echo "VARIABLES:"
	@echo "  KUBECTL_CONTEXT = $(KUBECTL_CONTEXT)"
	@echo
	@echo "TARGETS:"
	@grep -E '^.*: *# *@HELP' $(MAKEFILE_LIST)    \
	    | awk '                                   \
	        BEGIN {FS = ": *# *@HELP"};           \
	        { printf "  %-40s %s\n", $$1, $$2 };  \
	    '

kube.apply-kustomize: # @HELP Deploy omnitruck's kustomization
kube.apply-kustomize:
	kubectl --context $(KUBECTL_CONTEXT) apply -k .

kube.delete-kustomize: # @HELP Delete omnitruck's kustomization
kube.delete-kustomize:
	kubectl --context $(KUBECTL_CONTEXT) delete -k .

kube.follow-logs: # @HELP Follow omnitruck's pod's logs
kube.follow-logs:
	kubectl --context ${KUBECTL_CONTEXT} -n omnitruck \
		rollout status deployment/omnitruck --watch
	kubectl --context ${KUBECTL_CONTEXT} -n omnitruck \
		logs -f deployment/omnitruck -c omnitruck

linkerd.check: # @HELP Validate the health of linkerd
linkerd.check:
	linkerd --context $(KUBECTL_CONTEXT) check

linkerd.dashboard: # @HELP Open the linkerd web dashboard
linkerd.dashboard:
	linkerd --context $(KUBECTL_CONTEXT) dashboard

linkerd.install:  # @HELP Install linkerd 
linkerd.install:
	linkerd --context $(KUBECTL_CONTEXT) install | \
		kubectl --context  $(KUBECTL_CONTEXT) apply -f -
	$(MAKE) linkerd.check

linkerd.uninstall: # @HELP Uninstall linkerd 
linkerd.uninstall:
	linkerd --context $(KUBECTL_CONTEXT) install --ignore-cluster | \
		kubectl --context  $(KUBECTL_CONTEXT) delete -f -