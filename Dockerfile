FROM nvidia/cuda:8.0-devel-ubuntu16.04 as build

# Install basic development dependencies
RUN apt-get update && apt-get install -y \
    git \
    autoconf \
    build-essential \
    libass-dev \
    libtool \
    pkg-config \
    texinfo \
    zlib1g-dev \
    git

# Install NVENC dependencies
RUN apt-get update && apt-get -y install \
    glew-utils \
    libglew-dbg \
    libglew-dev \
    libglew1.13 \
    libglewmx-dev \
    libglewmx-dbg \
    freeglut3 \
    freeglut3-dev \
    freeglut3-dbg \
    libghc-glut-dev \
    libghc-glut-doc \
    libghc-glut-prof \
    libalut-dev \
    libxmu-dev \
    libxmu-headers \
    libxmu6 \
    libxmu6-dbg \
    libxmuu-dev \
    libxmuu1 \
    libxmuu1-dbg 

# Install FFmpeg dependencies
RUN apt-get update && apt-get -y install \
    autoconf \
    automake \
    build-essential \
    cmake \
    git \
    libass-dev \
    libfreetype6-dev \
    libsdl2-dev \
    libtheora-dev \
    libtool \
    libva-dev \
    libvpx-dev \
    libvdpau-dev \
    libvorbis-dev \
    libmp3lame-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    mercurial \
    pkg-config \
    texinfo \
    wget \
    zlib1g-dev \
    yasm

RUN mkdir -p /src/deps /install
ENV PATH="/install/usr/bin:/install/bin:${PATH}"


# Install nasm deps
RUN apt-get update && apt-get -y install \
    asciidoc

## NASM ##
WORKDIR /src/deps
RUN wget http://www.nasm.us/pub/nasm/releasebuilds/2.13.02/nasm-2.13.02.tar.gz \
        --output-document=/src/deps/nasm.tar.gz
RUN tar -xvf /src/deps/nasm.tar.gz
RUN mv /src/deps/nasm-* /src/deps/nasm
WORKDIR /src/deps/nasm
RUN ./autogen.sh && \
    ./configure --prefix=/install && \
    make -j$(nproc) && \
    make -j$(nproc) install


## FDK-AAC ##
WORKDIR /src/deps
RUN git clone --depth=1 https://github.com/mstorsjo/fdk-aac.git /src/deps/fdk-aac
WORKDIR /src/deps/fdk-aac
RUN autoreconf -fiv && \
    ./configure \
        --prefix=/install \
        --disable-shared \
        && \
    make -j$(nproc) && \
    make -j$(nproc) install


## LIBX264 ##
WORKDIR /src/deps
RUN git clone --depth=1 http://git.videolan.org/git/x264.git /src/deps/x264
WORKDIR /src/deps/x264
RUN ./configure \
        --prefix="/install" \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --disable-opencl \
        && \
    make -j$(nproc) && \
    make -j$(nproc) install


## LIBX265 ##
WORKDIR /src/deps
RUN hg clone https://bitbucket.org/multicoreware/x265
WORKDIR /src/deps/x265
RUN cd build/linux && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="/install" \
        -DENABLE_SHARED:bool=off \
        ../../source \
        && \
    make -j$(nproc) && \
    make -j$(nproc) install

## NVIDIA VIDEO CODEC SDK: NVDECODE/NVENCODE ##
WORKDIR /src/deps
RUN wget https://github.com/jniltinho/oficinadotux/raw/master/ffmpeg_nvenc/Video_Codec_SDK_8.0.14.zip \
    -O /src/deps/Video_Codec_SDK_8.0.14.zip
RUN unzip Video_Codec_SDK_8.0.14 && \
    cp -r Video_Codec_SDK_8.0.14/Samples/common/inc/ \
          /install/include/nvenc_sdk_9.0 && \
    cp -r Video_Codec_SDK_8.0.14/Samples/common/lib/ \
          /install/lib/nvenc_sdk_8.0


## FFMPEG ##
WORKDIR /src
RUN git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git /src/ffmpeg
WORKDIR /src/ffmpeg
ARG NVCC_ARCH="compute_60"
ARG NVCC_CODE="sm_60,sm_61,sm_62"
RUN export PKG_CONFIG_PATH="/install/lib/pkgconfig" && \
    ./configure \
        --prefix="/install" \
        --pkg-config-flags="--static" \
        --extra-cflags="-I/install/include" \
        --extra-ldflags="-L/install/lib" \
        --extra-cflags="-I/usr/local/cuda-${CUDA_VERSION%.*}/include" \
        --extra-ldflags=-L/usr/local/cuda-${CUDA_VERSION%.*}/lib \
        --extra-ldflags=-L/usr/local/cuda-${CUDA_VERSION%.*}/lib64 \
        --extra-cflags="-I/install/include/nvenc_sdk_8.0" \
        --extra-ldflags="-L/install/lib/nvenc_sdk_8.0" \
        --extra-libs="-lpthread -lm" \
        --nvccflags="--generate-code arch=$NVCC_ARCH,code=[$NVCC_CODE] -O2" \
        --enable-gpl \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-nonfree \
        --enable-cuda-sdk \
        --enable-cuvid \
        --enable-libnpp \
        --enable-nvenc \
        --enable-xlib \
        --disable-doc \
        --disable-debug \
        --disable-ffplay \
        && \
    make -j$(nproc) && \
    make -j$(nproc) install
RUN tar -cvf /src/ffmpeg-dynamic-deps.tar \
    $(ldd /install/bin/ffmpeg | \
      grep / | \
      awk '{ print $3 }' | \
      xargs readlink -f)

FROM nvidia/cuda:8.0-runtime-ubuntu16.04
RUN apt-get update && apt-get install -y \
     \
    && rm -rf /var/cache/apt


COPY --from=build /install/lib/* /usr/local/lib/
COPY --from=build /install/bin/* /usr/local/bin/
COPY --from=build /src/ffmpeg-dynamic-deps.tar /
RUN tar -xvf /ffmpeg-dynamic-deps.tar && \ 
    rm /ffmpeg-dynamic-deps.tar

ENV NVIDIA_VISIBLE_DEVICES all
# Without the following line, libnvcuvid.so.1 will not be mounted into
# the container, see
# https://github.com/NVIDIA/nvidia-docker/issues/531#issuecomment-343993909
# for further details, in nvidia/cuda:9.0 images the base image will
# set these for you
ENV NVIDIA_DRIVER_CAPABILITIES video,compute,utility
VOLUME /workspace
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/ffmpeg"]
CMD ["-h"]
