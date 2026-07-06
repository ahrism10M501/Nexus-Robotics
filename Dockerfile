FROM osrf/ros:jazzy-desktop

RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

ENV VENV_DIR="/opt/venv"
RUN uv venv $VENV_DIR --system-site-packages

RUN uv pip install --python $VENV_DIR \
    torch \
    torchvision \
    diffusers \
    huggingface_hub \
    einops \
    timm

RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "source $VENV_DIR/bin/activate" >> /root/.bashrc

WORKDIR /workspace
