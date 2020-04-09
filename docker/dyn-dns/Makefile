PHONY: all build test clean build-image push-image
.DEFAULT_GOAL := all

IMAGE ?= odoko/dyn-dns
IMAGE_TAG := latest

all: test build-image

build:
	GO111MODULE=on go build -o dyn-dns -v ./

test:
	GO111MODULE=on go test -v ./...

clean:
	rm -f ./dyn-dns
	go clean ./...

build-image:
	docker build -t $(IMAGE) .
	docker tag $(IMAGE) $(IMAGE):$(IMAGE_TAG)

push-image:
	docker push $(IMAGE):$(IMAGE_TAG)
	docker push $(IMAGE):latest
