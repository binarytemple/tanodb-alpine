setup-network:
	docker network create ci || true

setup-apk-cache: setup-network
	docker run --network ci --name=dl-cdn.alpinelinux.org quay.io/vektorcloud/apk-cache:latest || true

build: setup-apk-cache
	docker build --network ci --tag bryanhuntesl/tanodb-linux .

run:
	mkdir -p ./tanodb
	docker run --mount type=bind,source=$(shell pwd)/tanodb,target=/root/tanodb2 --network ci -ti bryanhuntesl/tanodb-linux /bin/bash
