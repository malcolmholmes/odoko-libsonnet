PHONY: all build test clean build-image push-image
.DEFAULT_GOAL := all

APP := backup
IMAGE ?= odoko/$(APP)
IMAGE_TAG := latest

all: test build-image

build:
	GO111MODULE=on go build -o $(APP) -v ./

test:
	GO111MODULE=on go test -v ./...

clean:
	rm -f ./$(APP)
	go clean ./...

build-image:
	docker build -t $(IMAGE) .
	docker tag $(IMAGE) $(IMAGE):$(IMAGE_TAG)

push-image: build-image
	docker push $(IMAGE):$(IMAGE_TAG)
#    docker push $(IMAGE):latest
