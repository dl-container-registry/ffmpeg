SHELL:=bash
CONTAINER_NAME:=willprice/nvidia-ffmpeg
SINGULARITY_NAME:=nvidia-ffmpeg.img
TAG:=


build:
	docker build -t $(CONTAINER_NAME) .

tag: version.txt

version.txt: build
	./tag.sh "$(CONTAINER_NAME)" > version.txt

push: tag
	docker push $(CONTAINER_NAME)

singularity: $(SINGULARITY_NAME)

$(SINGULARITY_NAME): tag
	singularity  build $@ Singularity
