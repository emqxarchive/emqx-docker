## default globals
TARGET ?= emqx/emqx
EMQX_DEPLOY ?= cloud
QEMU_ARCH ?= x86_64
ARCH ?= amd64
QEMU_VERSION ?= v4.0.0

## versioning
EMQX_VERSION ?= develop
BUILD_VERSION ?= $(EMQX_VERSION)

BROKER = $(subst emqx/,,$(TARGET))
ARCH_LIST = amd64 arm64v8 arm32v7 i386 s390x

.PHONY: all
all: build test tag

.PHONY: prepare
prepare:
	## Prepare the machine before any code installation scripts
	@echo "PREPARE: Setting up dependencies."
	@apt update -y
	@apt install --only-upgrade docker-ce -y
	
	## Update docker configuration to enable docker manifest command
	@echo "PREPARE: Updating docker configuration"
	@mkdir -p $$HOME/.docker

	# enable experimental to use docker manifest command
	@echo '{ "experimental": "enabled" }' | tee $$HOME/.docker/config.json
	# enable experimental
	@echo '{ "experimental": true, "storage-driver": "overlay2", "max-concurrent-downloads": 50, "max-concurrent-uploads": 50 }' | tee /etc/docker/daemon.json 
	@service docker restart

.PHONY: build
build:
	## Build Docker image
	@echo "DOCKER BUILD: Build Docker image."
	@echo "DOCKER BUILD: build version -> $(BUILD_VERSION)."
	@echo "DOCKER BUILD: build from -> $(BUILD_FROM)."
	@echo "DOCKER BUILD: arch - $(ARCH)."
	@echo "DOCKER BUILD: qemu arch - $(QEMU_ARCH)."
	@echo "DOCKER BUILD: docker repo - $(TARGET) "
	@echo "DOCKER BUILD: emqx deploy - $(EMQX_DEPLOY)."
	@echo "DOCKER BUILD: emqx version - $(EMQX_VERSION)."

	## Prepare qemu to build images other then x86_64 on travis
	@echo "PREPARE: Qemu" \
	&& docker run --rm --privileged multiarch/qemu-user-static:register --reset
    
	@mkdir -p tmp \
	&& cd tmp \
	&& curl -L -o qemu-$(QEMU_ARCH)-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/$(QEMU_VERSION)/qemu-$(QEMU_ARCH)-static.tar.gz \
	&& tar xzf qemu-$(QEMU_ARCH)-static.tar.gz \
	&& cd -

	@docker build --no-cache \
		--build-arg EMQX_DEPS_DEFAULT_VSN=$(EMQX_VERSION) \
		--build-arg BUILD_FROM=$(ARCH)/erlang:21.3-alpine  \
		--build-arg RUN_FROM=$(ARCH)/alpine:3.9 \
		--build-arg DEPLOY=$(EMQX_DEPLOY) \
		--build-arg QEMU_ARCH=$(QEMU_ARCH) \
		--tag $(TARGET):build-$(ARCH) .


key = $(shell date +%s)
aclient_name = "test-$(key)-$(BROKER)-docker-for-$(EMQX_VERSION)-$(ARCH)-aclient"
bclient_name = "test-$(key)-$(BROKER)-docker-for-$(EMQX_VERSION)-$(ARCH)-bclient"

define create_emqx_container
	if [ -z $$(docker network ls | grep emqxBridge | awk '{print $$2}') ]; then docker network create emqxBridge; fi

	docker run -d \
    -e EMQX_ZONE__EXTERNAL__SERVER_KEEPALIVE=60 \
    -e EMQX_MQTT__MAX_TOPIC_ALIAS=10 \
    -e EMQX_NAME=emqx \
    --network emqxBridge \
    --name $1 \
    $(TARGET):build-$(ARCH) \
	sh -c "sed -i '/deny/'d /opt/emqx/etc/acl.conf \
    && /usr/bin/start.sh"

	if [ -z $$(docker exec -i $1 sh -c "ls /opt/emqx/lib |grep emqx_cube") ] && [ "$(EMQX_DEPLOY)" = "edge" ]; then \
		echo "emqx $(EMQX_DEPLOY) deploy error"; \
		exit 1; \
	fi
  	if [ ! -z $$(docker exec -i $1 sh -c "ls /opt/emqx/lib |grep emqx_cube") ] && [ "$(EMQX_DEPLOY)" = "cloud" ]; then \
		echo "emqx $(EMQX_DEPLOY) deploy error"; \
		exit 1; \
	fi

	emqx_ver=$$(docker exec $1 /opt/emqx/bin/emqx_ctl status |grep 'is running'|awk '{print $$2}'); \
	IDLE_TIME=0; \
	while [ -z $$emqx_ver ]; do \
	if [ $$IDLE_TIME -gt 10 ]; then \
		echo "DOCKER TEST: FAILED - Docker container $1 failed to start."; exit 1; \
	fi; \
	sleep 10; \
	IDLE_TIME=$$((IDLE_TIME+1)); \
	emqx_ver=$$(docker exec $1 /opt/emqx/bin/emqx_ctl status |grep 'is running'|awk '{print $$2}'); \
	done
endef

.PHONY: test
test:
	$(call create_emqx_container,$(aclient_name))
	$(call create_emqx_container,$(bclient_name))

	# create cluster
	aclient_ip=$$(docker inspect -f '{{ .NetworkSettings.Networks.emqxBridge.IPAddress}}' $(aclient_name)); \
	bclient_ip=$$(docker inspect -f '{{ .NetworkSettings.Networks.emqxBridge.IPAddress}}' $(bclient_name)); \
	docker exec -i $(bclient_name) sh -c "emqx_ctl cluster join emqx@$${aclient_ip}" ; \
	cluster=$$(docker exec -i $(bclient_name) sh -c "emqx_ctl cluster status"); \
	nodes=$$(echo $${cluster} | grep -P 'emqx@((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])' -o); \
	if [ -z $$(echo $${nodes} | grep "emqx@$${aclient_ip}" -o) ] || [ -z $$(echo $${nodes} | grep "emqx@$${bclient_ip}" -o) ];then \
		echo "DOCKER TEST: FAILED - Create cluster failed"; \
		exit 1; \
	fi; \

	# Paho test
	docker run -i --rm --network emqxBridge python:3.7.2-alpine3.9 \
	sh -c "apk update && apk add git \
	&& git clone -b master https://github.com/emqx/paho.mqtt.testing.git /paho.mqtt.testing \
	&& sed -i '/host = \"localhost\"/c \ \ host = \"$(aclient_name)\"' /paho.mqtt.testing/interoperability/client_test5.py \
	&& sed -i '/aclientHost = \"localhost\"/c \ \ aclientHost = \"$(aclient_name)\"' /paho.mqtt.testing/interoperability/client_test5.py \
	&& sed -i '/bclientHost = \"localhost\"/c \ \ bclientHost = \"$(bclient_name)\"' /paho.mqtt.testing/interoperability/client_test5.py \
	&& python /paho.mqtt.testing/interoperability/client_test5.py"

	docker rm -f $(aclient_name) $(bclient_name)

.PHONY: tag
tag:
	@echo "DOCKER TAG: Tag Docker image."
	@for arch in $(ARCH_LIST); do \
		if [ -n  "$$(docker images -q $(TARGET):build$${arch})" ]; then \
			docker tag $(TARGET):build$${arch}  $(TARGET):$(BUILD_VERSION)-$${arch}; \
			echo "DOCKER TAG: $(TARGET):$(BUILD_VERSION)-$${arch}"; \
			if [ $${arch} = amd64 ]; then \
				docker tag $(TARGET):$(BUILD_VERSION)-amd64 $(TARGET):$(BUILD_VERSION); \
				echo "DOCKER TAG: $(TARGET):$(BUILD_VERSION)"; \
			fi; \
		fi; \
	done

.PHONY: save
save:
	@echo "DOCKER SAVE: Save Docker image." 

	@if [ -n  "$$(docker images -q $(TARGET):$(BUILD_VERSION))" ]; then \
		docker save $(TARGET):$(BUILD_VERSION) > $(BROKER)-docker-$(BUILD_VERSION); \
		zip -r -m $(BROKER)-docker-$(BUILD_VERSION).zip $(BROKER)-docker-$(BUILD_VERSION); \
	fi
	
	@for arch in $(ARCH_LIST); do \
		if [ -n  "$$(docker images -q  $(TARGET):$(BUILD_VERSION)-$${arch})" ]; then \
			docker save  $(TARGET):$(BUILD_VERSION)-$${arch} > $(BROKER)-docker-$(BUILD_VERSION)-$${arch}; \
			zip -r -m $(BROKER)-docker-$(BUILD_VERSION)-$${arch}.zip $(BROKER)-docker-$(BUILD_VERSION)-$${arch}; \
		fi; \
	done

.PHONY: push
push:
	@echo "DOCKER PUSH: Push Docker image."; 
	@echo "DOCKER PUSH: pushing - $(TARGET):$(BUILD_VERSION)."; 

	@if [ -n "$$(docker images -q $(TARGET):$(BUILD_VERSION))" ]; then \
		docker push $(TARGET):$(BUILD_VERSION); \
		docker tag $(TARGET):$(BUILD_VERSION) $(TARGET):latest; \
		docker push $(TARGET):latest; \
	fi;

	@for arch in $(ARCH_LIST); do \
		if [ -n "$$(docker images -q  $(TARGET):$(BUILD_VERSION)-$${arch})" ]; then \
			docker push  $(TARGET):$(BUILD_VERSION)-$${arch}; \
		fi; \
	done

.PHONY: manifest_list
manifest_list:
	@if [ ! -z $$(echo $(EMQX_VERSION) | grep -oE "v[0-9]+\.[0-9]+(\.[0-9]+)?") ] &&  [ -n  "$$(docker images -q  $(TARGET):$(BUILD_VERSION)" ] &&  [ -n  "$$(docker images -q  $(TARGET):latest" ];then \
		version="docker manifest create --amend $(TARGET):$(BUILD_VERSION)"; \
		latest="docker manifest create --amend $(TARGET):latest"; \
		for arch in $(ARCH_LIST); do \
			version="$${version} $(TARGET):$(BUILD_VERSION)-$${arch} "; \
			latest="$${latest} $(TARGET):$(BUILD_VERSION)-$${arch} "; \
			case $${arch} in \
				"amd64") \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-amd64 $(TARGET):$(BUILD_VERSION)-amd64; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION)-amd64 $(TARGET):$(BUILD_VERSION)-amd64 --os=linux --arch=x86_64; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION) $(TARGET):$(BUILD_VERSION)-amd64 --os=linux --arch=x86_64; \
					docker manifest annotate $(TARGET):latest $(TARGET):$(BUILD_VERSION)-amd64 --os=linux --arch=x86_64; \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-amd64 $(TARGET):$(BUILD_VERSION)-amd64; \
					;; \
				"arm64v8") \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-arm64v8 $(TARGET):$(BUILD_VERSION)-arm64v8; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION)-arm64v8 $(TARGET):$(BUILD_VERSION)-arm64v8 --os=linux --arch=arm64 --variant=v8; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION) $(TARGET):$(BUILD_VERSION)-arm64v8 --os=linux --arch=arm64 --variant=v8; \
					docker manifest annotate $(TARGET):latest $(TARGET):$(BUILD_VERSION)-arm64v8 --os=linux --arch=arm64 --variant=v8; \
					;; \
				"arm32v7") \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-arm32v7 $(TARGET):$(BUILD_VERSION)-arm32v7; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION)-arm32v7 $(TARGET):$(BUILD_VERSION)-arm32v7 --os=linux --arch=arm --variant=v7; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION) $(TARGET):$(BUILD_VERSION)-arm32v7 --os=linux --arch=arm --variant=v7; \
					docker manifest annotate $(TARGET):latest $(TARGET):$(BUILD_VERSION)-arm32v7 --os=linux --arch=arm --variant=v7; \
					;; \
				"i386") \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-i386 $(TARGET):$(BUILD_VERSION)-i386; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION)-i386 $(TARGET):$(BUILD_VERSION)-i386 --os=linux --arch=386; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION) $(TARGET):$(BUILD_VERSION)-i386 --os=linux --arch=386; \
					docker manifest annotate $(TARGET):latest $(TARGET):$(BUILD_VERSION)-i386 --os=linux --arch=386; \
					;; \
				"s390x") \
					docker manifest create --amend $(TARGET):$(BUILD_VERSION)-s390x $(TARGET):$(BUILD_VERSION)-s390x; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION)-s390x $(TARGET):$(BUILD_VERSION)-s390x --os=linux --arch=s390x; \
					docker manifest annotate $(TARGET):$(BUILD_VERSION) $(TARGET):$(BUILD_VERSION)-s390x --os=linux --arch=s390x; \
					docker manifest annotate $(TARGET):latest $(TARGET):$(BUILD_VERSION)-s390x --os=linux --arch=s390x; \
					;; \
			esac; \
			docker manifest push $(TARGET):$(BUILD_VERSION)-$${arch}
		done; \
		eval $$version; \
		eval $$latest; \
		docker manifest push $(TARGET):$(BUILD_VERSION); \
		docker manifest push $(TARGET):latest; \
	fi

.PHONY: clean
clean:
	@echo "DOCKER CLEAN: Clean Docker image."

	@if [ -n "$$(docker images -q  $(TARGET):$(BUILD_VERSION))" ]; then docker rmi -f $$(docker images -q  $(TARGET):$(BUILD_VERSION)); fi

	@for arch in $(ARCH_LIST); do \
		if [ -n "$$(docker images -q  $(TARGET):$(BUILD_VERSION)-$${arch})" ]; then \
			docker rmi -f $$(docker images -q  $(TARGET):$(BUILD_VERSION)-$${arch}); \
		fi \
	done
