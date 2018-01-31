SHELL:=bash
CONTAINER_NAME:=willprice/nvidia-ffmpeg
SINGULARITY_NAME:=nvidia-ffmpeg.img
TAG:=


.PHONY: build
build:
	docker build -t $(CONTAINER_NAME) .

version.txt: build
	./tag.sh "$(CONTAINER_NAME)" > version.txt

.PHONY: push
push: version.txt
	docker push $(CONTAINER_NAME)

.PHONY: singularity
singularity: $(SINGULARITY_NAME)

$(SINGULARITY_NAME): tag
	singularity  build $@ Singularity
