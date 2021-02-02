SHORT_NAME ?= slugbuilder
DRYCC_REGISTRY ?= ${DEV_REGISTRY}
PLATFORM ?= linux/amd64,linux/arm64

export GO15VENDOREXPERIMENT=1

# Note that Minio currently uses CGO.

LDFLAGS := "-s -X main.version=${VERSION}"
IMAGE_PREFIX ?= drycc
BINDIR := ./rootfs/bin

include versioning.mk

SHELL_SCRIPTS = $(wildcard _scripts/*.sh) \
				$(wildcard rootfs/builder/*) \
				$(wildcard rootfs/installer/*) \
				rootfs/usr/local/bin/get_object \
				rootfs/usr/local/bin/normalize_storage \
				rootfs/usr/local/bin/put_object \
				rootfs/usr/local/bin/restore_cache \
				rootfs/usr/local/bin/store_cache

# The following variables describe the containerized development environment
# and other build options
DEV_ENV_IMAGE := ${DEV_REGISTRY}/drycc/go-dev
DEV_ENV_WORK_DIR := /go/src/${REPO_PATH}
DEV_ENV_CMD := docker run --rm -v ${CURDIR}:${DEV_ENV_WORK_DIR} -w ${DEV_ENV_WORK_DIR} ${DEV_ENV_IMAGE}
DEV_ENV_CMD_INT := docker run -it --rm -v ${CURDIR}:${DEV_ENV_WORK_DIR} -w ${DEV_ENV_WORK_DIR} ${DEV_ENV_IMAGE}

all: build docker-build docker-push

bootstrap:
	@echo Nothing to do.

build:
	@echo Nothing to do.

docker-build:
	docker build ${DOCKER_BUILD_FLAGS} --build-arg STACK=${STACK} -t ${IMAGE} -f rootfs/Dockerfile rootfs
	docker tag ${IMAGE} ${MUTABLE_IMAGE}

docker-buildx:
	docker buildx build --platform ${PLATFORM} ${DOCKER_BUILD_FLAGS} --build-arg STACK=${STACK} -t ${IMAGE} -f rootfs/Dockerfile rootfs --push

deploy: docker-build docker-push

kube-pod: kube-service
	kubectl create -f ${POD}

kube-secrets:
	- kubectl create -f ${SEC}

secrets:
	perl -pi -e "s|access-key-id: .+|access-key-id: ${key}|g" ${SEC}
	perl -pi -e "s|access-secret-key: .+|access-secret-key: ${secret}|g" ${SEC}
	echo ${key} ${secret}

kube-service: kube-secrets
	- kubectl create -f ${SVC}

kube-clean:
	- kubectl delete rc drycc-${SHORT_NAME}-rc

test: test-style test-unit test-functional

test-style:
	${DEV_ENV_CMD} shellcheck $(SHELL_SCRIPTS)

test-unit:
	docker run --entrypoint /usr/bin/env ${IMAGE} python3 -m unittest procfile

test-functional:
	@echo "Implement functional tests in _tests directory"

.PHONY: all bootstrap build docker-build docker-push deploy kube-pod kube-secrets \
	secrets kube-service kube-clean test
