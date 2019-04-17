SHELL:=bash
BASE_NAME:=nvidia-ffmpeg
CONTAINER_NAME:=willprice/$(BASE_NAME)
SINGULARITY_NAME:=$(BASE_NAME).simg
TAG:=latest

.PHONY: build
build:
	docker build -t $(CONTAINER_NAME):$(TAG) .

version.txt: build
	./tag.sh "$(CONTAINER_NAME)" > version.txt

.PHONY: push
push: version.txt
	docker push $(CONTAINER_NAME):$(TAG)

.PHONY: singularity
singularity: $(SINGULARITY_NAME)

$(SINGULARITY_NAME): tag
	singularity  build $@ Singularity
