FROM balenalib/jetson-nano-ubuntu:bionic as buildstep

WORKDIR /usr/src/app

COPY ./cuda-repo-l4t-10-2-local-10.2.89_1.0-1_arm64.deb .
COPY ./libcudnn8_8.0.0.180-1+cuda10.2_arm64.deb .
COPY ./libcudnn8-dev_8.0.0.180-1+cuda10.2_arm64.deb .

ENV DEBIAN_FRONTEND noninteractive

RUN \
    dpkg -i cuda-repo-l4t-10-2-local-10.2.89_1.0-1_arm64.deb \
    libcudnn8_8.0.0.180-1+cuda10.2_arm64.deb \
    libcudnn8-dev_8.0.0.180-1+cuda10.2_arm64.deb && \
    apt-key add /var/cuda-repo-10-2-local-10.2.89/*.pub && \
    apt-get update && \
    apt-get install cuda-compiler-10-2 cuda-samples-10-2 -y && \
    rm -rf *.deb && \
    dpkg --remove cuda-repo-l4t-10-2-local-10.2.89 && \
    dpkg -P cuda-repo-l4t-10-2-local-10.2.89 && \
    echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf && \
    ldconfig

RUN \
    export SMS=53 && \
    cd /usr/local/cuda-10.2/samples/0_Simple/clock/ && make -j8 && \
    cd /usr/local/cuda-10.2/samples/1_Utilities/deviceQuery/ && make -j8 && \
    cd /usr/local/cuda-10.2/samples/2_Graphics/simpleTexture3D/ && make -j8 && \
    cd /usr/local/cuda-10.2/samples/2_Graphics/simpleGL/ && make -j8 && \
    cd /usr/local/cuda-10.2/samples/3_Imaging/postProcessGL/ && make -j8 && \
    cd /usr/local/cuda-10.2/samples/5_Simulations/smokeParticles && make -j8

# Some CUDA libraries are very large and not
# all examples need them. Free up some more space

RUN \
    rm -rf /usr/local/cuda-10.2/targets && \
    rm -rf /usr/local/cuda-10.2/doc

FROM balenalib/jetson-nano-ubuntu:bionic as final

COPY --from=buildstep /usr/local/cuda-10.2 /usr/local/cuda-10.2

# If planning to only use GPU API, without CUDA runtime API,
# the two lines below can be commented out
COPY --from=buildstep /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=buildstep /usr/local/lib /usr/local/lib

COPY ./nvidia_drivers.tbz2 .
COPY ./config.tbz2 .

ENV DEBIAN_FRONTEND noninteractive

# If planning to do only headles GPU computing, without video
# display do not install xorg
RUN apt-get update && apt-get install lbzip2 xorg -y && \
    tar xjf nvidia_drivers.tbz2 -C / && \
    tar xjf config.tbz2 -C / --exclude=etc/hosts --exclude=etc/hostname && \
    echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf && ldconfig && \
    rm -rf *.tbz2

ENV UDEV=1

WORKDIR /usr/local/cuda-10.0/samples/bin/aarch64/linux/release

CMD [ "sleep", "infinity" ]
