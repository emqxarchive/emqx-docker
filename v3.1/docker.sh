#!/bin/sh

set -ex

# default globals
TARGET="${TARGET:-emqx/emqx}"
EMQX_DEPLOY="${EMQX_DEPLOY:-cloud}"
QEMU_ARCH="${QEMU_ARCH:-x86_64}"
ARCH="${ARCH:-amd64}"
QEMU_VERSION="${QEMU_VERSION:-v4.0.0}"

# versioning
EMQX_VERSION="${EMQX_VERSION:-${TAG_VSN:-develop}}"

main() {
    case $1 in
        "prepare")
            docker_prepare
            ;;
        "build")
            docker_build
            ;;
        "test")
            docker_test
            ;;
        "tag")
            docker_tag
            ;;
        "save")
            docker_save
            ;;
        "push")
            docker_push
            ;;
        "clean")
            docker_clean
            ;;
        "manifest-list")
            docker_manifest_list
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

usage() {
    echo "Usage:"
    echo "$0 prepare | build | test | tag | save | push | clean | manifest-list"
}

docker_prepare() {
    # Prepare the machine before any code installation scripts
    setup_dependencies

    # Update docker configuration to enable docker manifest command
    update_docker_configuration
}

docker_build() {
  # Build Docker image
  echo "DOCKER BUILD: Build Docker image."
  echo "DOCKER BUILD: build from -> ${BUILD_FROM}."
  echo "DOCKER BUILD: arch - ${ARCH}."
  echo "DOCKER BUILD: qemu arch - ${QEMU_ARCH}."
  echo "DOCKER BUILD: docker repo - ${TARGET}. "
  echo "DOCKER BUILD: emqx deploy - ${EMQX_DEPLOY}."
  echo "DOCKER BUILD: emqx version - ${EMQX_VERSION}."

  # Prepare qemu to build images other then x86_64 on travis
  prepare_qemu

  docker build --no-cache \
    --build-arg EMQX_DEPS_DEFAULT_VSN=${EMQX_VERSION} \
    --build-arg BUILD_FROM=${ARCH}/erlang:21.3.6-alpine  \
    --build-arg RUN_FROM=${ARCH}/alpine:3.9 \
    --build-arg DEPLOY=${EMQX_DEPLOY} \
    --build-arg QEMU_ARCH=${QEMU_ARCH} \
    --tag ${TARGET}:build-${ARCH} .
}

docker_test() {
  echo "DOCKER TEST: Test Docker image."
  echo "DOCKER TEST: testing image -> ${TARGET}:build-${ARCH}."

  name=test_emqx_docker_for_${ARCH}

  [ -z $(docker network ls |grep emqx-net) ] && docker network create emqx-net

  docker run -d \
    -e EMQX_ZONE__EXTERNAL__SERVER_KEEPALIVE=60 \
    -e EMQX_MQTT__MAX_TOPIC_ALIAS=10 \
    --network emqx-net \
    --name ${name} \
    ${TARGET}:build-${ARCH} \
    sh -c "sed -i '/deny/'d /opt/emqx/etc/acl.conf \
    && /usr/bin/start.sh"

  [ -z $(docker exec ${name} sh -c "ls /opt/emqx/lib |grep emqx_storm") && ${EMQX_DEPLOY} == "edge" ] && echo "emqx ${EMQX_DEPLOY} deploy error" && exit 1
  [ ! -z $(docker exec ${name} sh -c "ls /opt/emqx/lib |grep emqx_storm") && ${EMQX_DEPLOY} == "cloud" ] && echo "emqx ${EMQX_DEPLOY} deploy error" && exit 1

  emqx_ver=$(docker exec ${name} /opt/emqx/bin/emqx_ctl status |grep 'is running'|awk '{print $2}')
  IDLE_TIME=0
  while [ -z $emqx_ver ]
  do
  if [ $IDLE_TIME -gt 10 ]
      then
        echo "DOCKER TEST: FAILED - Docker container ${name} failed to start."
        exit 1
      fi
      sleep 10
      IDLE_TIME=$((IDLE_TIME+1))
      emqx_ver=$(docker exec ${name} /opt/emqx/bin/emqx_ctl status |grep 'is running'|awk '{print $2}')
  done
  if [ ! -z $(echo $EMQX_VERSION | grep -oE "v[0-9]+\.[0-9]+(\.[0-9]+)?") && $EMQX_VERSION != $emqx_ver ]
  then
      echo "DOCKER TEST: FAILED - Docker container ${name} version error."
      exit 1 
  fi
  echo "DOCKER TEST: PASSED - Docker container ${name} succeeded to start."
  # Paho test
  docker run -i --rm --network emqx-net python:3.7.2-alpine3.9 \
  sh -c "apk update && apk add git \
  && git clone -b master https://github.com/emqx/paho.mqtt.testing.git /paho.mqtt.testing \
  && sed -i \"s/localhost/${name}/g\" /paho.mqtt.testing/interoperability/client_test5.py \
  && python /paho.mqtt.testing/interoperability/client_test5.py"
  docker rm -f ${name}
}


docker_tag() {
    echo "DOCKER TAG: Tag Docker image."
    [ -n  $(docker images -q ${TARGET}:build-s390x) ] && docker tag ${TARGET}:build-s390x ${TARGET}:${EMQX_VERSION}-s390x
    [ -n  $(docker images -q ${TARGET}:build-i386) ] && docker tag ${TARGET}:build-i386 ${TARGET}:${EMQX_VERSION}-i386
    [ -n  $(docker images -q ${TARGET}:build-arm32v7) ] && docker tag ${TARGET}:build-arm32v7 ${TARGET}:${EMQX_VERSION}-arm32v7
    [ -n  $(docker images -q ${TARGET}:build-arm64v8) ] && docker tag ${TARGET}:build-arm64v8 ${TARGET}:${EMQX_VERSION}-arm64v8
    [ -n  $(docker images -q ${TARGET}:build-amd64) ] &&  docker tag ${TARGET}:build-amd64 ${TARGET}:${EMQX_VERSION}-amd64 &&  docker tag ${TARGET}:build-amd64 ${TARGET}:${EMQX_VERSION} 
}

docker_save() {
    echo "DOCKER SAVE: Save Docker image."  
    filename=${TARGET#"emqx/"}
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && docker save ${TARGET}:${EMQX_VERSION}-s390x > ${filename}-docker-${EMQX_VERSION}-s390x && zip -r -m ${filename}-docker-${EMQX_VERSION}-s390x.zip ${filename}-docker-${EMQX_VERSION}-s390x
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && docker save ${TARGET}:${EMQX_VERSION}-i386 > ${filename}-docker-${EMQX_VERSION}-i386 && zip -r -m ${filename}-docker-${EMQX_VERSION}-i386.zip ${filename}-docker-${EMQX_VERSION}-i386
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && docker save ${TARGET}:${EMQX_VERSION}-arm32v7 > ${filename}-docker-${EMQX_VERSION}-arm32v7 && zip -r -m ${filename}-docker-${EMQX_VERSION}-arm32v7.zip ${filename}-docker-${EMQX_VERSION}-arm32v7
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ] && docker save ${TARGET}:${EMQX_VERSION}-arm64v8 > ${filename}-docker-${EMQX_VERSION}-arm64v8 && zip -r -m ${filename}-docker-${EMQX_VERSION}-arm64v8.zip ${filename}-docker-${EMQX_VERSION}-arm64v8 
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64) ] && docker save ${TARGET}:${EMQX_VERSION}-amd64 > ${filename}-docker-${EMQX_VERSION}-amd64 && zip -r -m ${filename}-docker-${EMQX_VERSION}-amd64.zip ${filename}-docker-${EMQX_VERSION}-amd64 
    [ -n  $(docker images -q ${TARGET}:${EMQX_VERSION}) ] && docker save ${TARGET}:${EMQX_VERSION} > ${filename}-docker-${EMQX_VERSION} && zip -r -m ${filename}-docker-${EMQX_VERSION}.zip ${filename}-docker-${EMQX_VERSION}
}

docker_push() {
  echo "DOCKER PUSH: Push Docker image."
  echo "DOCKER PUSH: pushing - ${TARGET}:${EMQX_VERSION}."
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && docker push ${TARGET}:${EMQX_VERSION}-s390x 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && docker push ${TARGET}:${EMQX_VERSION}-i386 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && docker push ${TARGET}:${EMQX_VERSION}-arm32v7 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ] && docker push ${TARGET}:${EMQX_VERSION}-arm64v8 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64) ] && docker push ${TARGET}:${EMQX_VERSION}-amd64  
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}) ] && docker push ${TARGET}:${EMQX_VERSION}

  if [ ! -z $(echo $EMQX_VERSION | grep -oE "v[0-9]+\.[0-9]+(\.[0-9]+)?") ];then
    docker tag ${TARGET}:${EMQX_VERSION} ${TARGET}:latest
    docker push ${TARGET}:latest
  fi
}

docker_clean() {
  echo "DOCKER CLEAN: Clean Docker image."
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && docker rmi -f $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && docker rmi -f $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && docker rmi -f $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ] && docker rmi -f $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) 
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64) ] && docker rmi -f $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64)
}

docker_manifest_list() {
  echo "DOCKER BUILD: target -> ${TARGET}."
  echo "DOCKER BUILD: build version -> ${EMQX_VERSION}."

  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64) ] || { echo "${TARGET}:${EMQX_VERSION}-amd64 does not exist."; exit 1; } 

  # Create and push manifest lists, displayed as FIFO
  echo "DOCKER MANIFEST: Create and Push docker manifest lists."
  docker_manifest_list_version

  # Create manifest list latest
  echo "DOCKER MANIFEST: Create and Push docker manifest list LATEST."
  docker_manifest_list_latest;

  docker_manifest_list_version_os_arch
}

docker_manifest_list_version() {
  # Manifest Create EMQX_VERSION
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}."
  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:${EMQX_VERSION} \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8 \
      ${TARGET}:${EMQX_VERSION}-i386 \
      ${TARGET}:${EMQX_VERSION}-s390x 
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:${EMQX_VERSION} \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8 \
      ${TARGET}:${EMQX_VERSION}-i386
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:${EMQX_VERSION} \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:${EMQX_VERSION} \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm64v8
  else 
    docker manifest create --amend ${TARGET}:${EMQX_VERSION} \
      ${TARGET}:${EMQX_VERSION}-amd64 
  fi

  # Manifest Annotate EMQX_VERSION
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && docker manifest annotate ${TARGET}:${EMQX_VERSION} ${TARGET}:${EMQX_VERSION}-s390x --os=linux --arch=s390x
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && docker manifest annotate ${TARGET}:${EMQX_VERSION} ${TARGET}:${EMQX_VERSION}-i386 --os=linux --arch=386
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && docker manifest annotate ${TARGET}:${EMQX_VERSION} ${TARGET}:${EMQX_VERSION}-arm32v7 --os=linux --arch=arm --variant=v7
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ] && docker manifest annotate ${TARGET}:${EMQX_VERSION} ${TARGET}:${EMQX_VERSION}-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push EMQX_VERSION
  docker manifest push ${TARGET}:${EMQX_VERSION}
}

docker_manifest_list_latest() {
  # Manifest Create latest
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:latest."
  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:latest \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8 \
      ${TARGET}:${EMQX_VERSION}-i386 \
      ${TARGET}:${EMQX_VERSION}-s390x 
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:latest \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8 \
      ${TARGET}:${EMQX_VERSION}-i386
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:latest \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm64v8
  elif [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    docker manifest create --amend ${TARGET}:latest \
      ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-arm64v8
  else
    docker manifest create --amend ${TARGET}:latest \
    ${TARGET}:${EMQX_VERSION}-amd64 
  fi

  # Manifest Annotate EMQX_VERSION
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ] && docker manifest annotate ${TARGET}:latest ${TARGET}:${EMQX_VERSION}-s390x --os=linux --arch=s390x
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ] && docker manifest annotate ${TARGET}:latest ${TARGET}:${EMQX_VERSION}-i386 --os=linux --arch=386
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ] && docker manifest annotate ${TARGET}:latest ${TARGET}:${EMQX_VERSION}-arm32v7 --os=linux --arch=arm --variant=v7
  [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ] && docker manifest annotate ${TARGET}:latest ${TARGET}:${EMQX_VERSION}-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push EMQX_VERSION
  docker manifest push ${TARGET}:latest
}

docker_manifest_list_version_os_arch() {
  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-amd64) ];then
    # Manifest Create alpine-amd64
    echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}-amd64."
    docker manifest create --amend ${TARGET}:${EMQX_VERSION}-amd64 \
      ${TARGET}:${EMQX_VERSION}-amd64

    # Manifest Push alpine-amd64
    docker manifest push ${TARGET}:${EMQX_VERSION}-amd64
  fi

  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm32v7) ];then
    # Manifest Create alpine-arm32v7
    echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}-arm32v7."
    docker manifest create --amend ${TARGET}:${EMQX_VERSION}-arm32v7 \
      ${TARGET}:${EMQX_VERSION}-arm32v7

    # Manifest Annotate alpine-arm32v7
    docker manifest annotate ${TARGET}:${EMQX_VERSION}-arm32v7 ${TARGET}:${EMQX_VERSION}-arm32v7 --os=linux --arch=arm --variant=v7

    # Manifest Push alpine-arm32v7
    docker manifest push ${TARGET}:${EMQX_VERSION}-arm32v7
  fi

  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-arm64v8) ];then
    # Manifest Create alpine-arm64v8
    echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}-arm64v8."
    docker manifest create --amend ${TARGET}:${EMQX_VERSION}-arm64v8 \
      ${TARGET}:${EMQX_VERSION}-arm64v8

    # Manifest Annotate alpine-arm64v8
    docker manifest annotate ${TARGET}:${EMQX_VERSION}-arm64v8 ${TARGET}:${EMQX_VERSION}-arm64v8 --os=linux --arch=arm64 --variant=v8

    # Manifest Push alpine-arm64v8
    docker manifest push ${TARGET}:${EMQX_VERSION}-arm64v8
  fi

  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-i386) ];then
    # Manifest Create alpine-i386
    echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}-i386."
    docker manifest create --amend ${TARGET}:${EMQX_VERSION}-i386 \
      ${TARGET}:${EMQX_VERSION}-i386

    # Manifest Push alpine-i386
    docker manifest push ${TARGET}:${EMQX_VERSION}-i386
  fi
  if [ -n $(docker images -q ${TARGET}:${EMQX_VERSION}-s390x) ];then
    # Manifest Create alpine-s390x
    echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${EMQX_VERSION}-s390x."
    docker manifest create --amend ${TARGET}:${EMQX_VERSION}-s390x \
      ${TARGET}:${EMQX_VERSION}-s390x

    # Manifest Push alpine-s390x
    docker manifest push ${TARGET}:${EMQX_VERSION}-s390x
  fi
}

setup_dependencies() {
  echo "PREPARE: Setting up dependencies."

  apt update -y
  apt install --only-upgrade docker-ce -y
}

update_docker_configuration() {
  echo "PREPARE: Updating docker configuration"

  mkdir -p $HOME/.docker

  # enable experimental to use docker manifest command
  echo '{
    "experimental": "enabled"
  }' | tee $HOME/.docker/config.json

  # enable experimental
  echo '{
    "experimental": true,
    "storage-driver": "overlay2",
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50
  }' | tee /etc/docker/daemon.json

  service docker restart
}

prepare_qemu(){
    echo "PREPARE: Qemu"
    # Prepare qemu to build non amd64 / x86_64 images
    docker run --rm --privileged multiarch/qemu-user-static:register --reset
    rm -rf tmp
    mkdir -p tmp
    cd tmp &&
    curl -L -o qemu-${QEMU_ARCH}-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/$QEMU_VERSION/qemu-${QEMU_ARCH}-static.tar.gz && tar xzf qemu-${QEMU_ARCH}-static.tar.gz &&
    cd -
}

main $1