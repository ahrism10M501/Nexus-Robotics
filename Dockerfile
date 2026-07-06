FROM osrf/ros:jazzy-desktop

RUN apt-get update && apt-get install -y \
    bash-completion \
    build-essential \
    curl \
    git \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENV VENV_DIR="/opt/venv"
ENV PATH="${VENV_DIR}/bin:/root/.local/bin:${PATH}"

RUN uv venv $VENV_DIR --system-site-packages

RUN uv pip install --python $VENV_DIR \
    torch \
    torchvision \
    diffusers \
    huggingface_hub \
    einops \
    timm

COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash

RUN echo "source /etc/profile.d/nexus_env.bash" >> /root/.bashrc

WORKDIR /workspace
