# syntax=docker/dockerfile:1.7
ARG ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36
FROM ${UV_IMAGE} AS uv-bin
FROM ${ROS_BASE_IMAGE} AS ros-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEVELOPER_UID=1000
ARG DEVELOPER_GID=1000
ENV DEBIAN_FRONTEND=noninteractive
ENV VENV_DIR=/opt/venv
ENV PATH="${VENV_DIR}/bin:${PATH}"

COPY --from=uv-bin /uv /uvx /usr/local/bin/
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl sudo \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    test "${DEVELOPER_UID}" -gt 0; \
    test "${DEVELOPER_GID}" -gt 0; \
    gid_name="$(getent group "${DEVELOPER_GID}" | cut -d: -f1 || true)"; \
    if [[ -n "${gid_name}" && "${gid_name}" != developer ]]; then \
      groupmod --new-name developer "${gid_name}"; \
    elif [[ -z "${gid_name}" ]]; then \
      groupadd --gid "${DEVELOPER_GID}" developer; \
    fi; \
    uid_name="$(getent passwd "${DEVELOPER_UID}" | cut -d: -f1 || true)"; \
    if [[ -n "${uid_name}" && "${uid_name}" != developer ]]; then \
      usermod --login developer --home /home/developer --move-home \
        --gid "${DEVELOPER_GID}" --shell /bin/bash "${uid_name}"; \
    elif [[ -z "${uid_name}" ]]; then \
      useradd --uid "${DEVELOPER_UID}" --gid "${DEVELOPER_GID}" \
        --create-home --home-dir /home/developer --shell /bin/bash developer; \
    else \
      usermod --gid "${DEVELOPER_GID}" --home /home/developer \
        --move-home --shell /bin/bash developer; \
    fi; \
    test "$(id -u developer)" = "${DEVELOPER_UID}"; \
    test "$(id -g developer)" = "${DEVELOPER_GID}"; \
    printf 'developer ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/developer; \
    chmod 0440 /etc/sudoers.d/developer; \
    touch /home/developer/.bashrc; \
    install -d -o developer -g developer /workspace /opt/venv; \
    chown developer:developer /home/developer/.bashrc /workspace /opt/venv
COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash
RUN printf '\nsource /etc/profile.d/nexus_env.bash\n' >> /home/developer/.bashrc \
    && chown developer:developer /home/developer/.bashrc
WORKDIR /workspace
USER developer

FROM ros-base AS ros-dev
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gdb git iproute2 iputils-ping jq less lsof net-tools procps \
      python3-colcon-common-extensions python3-pip python3-rosdep python3-vcstool \
      ros-jazzy-desktop ros-jazzy-rmw-fastrtps-cpp \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
USER developer

FROM ros-dev AS ros-python-dev
USER root
RUN uv venv "${VENV_DIR}" --system-site-packages \
    && "${VENV_DIR}/bin/python" -c \
      'import sys; assert sys.version_info[:2] == (3, 12), sys.version' \
    && test "$(uv --version)" = 'uv 0.8.3' \
    && chown -R developer:developer "${VENV_DIR}"
WORKDIR /workspace
USER developer

FROM ros-python-dev AS ros-ai-dev
USER root
COPY docker/requirements/ai.lock /tmp/ai.lock
RUN uv pip sync --require-hashes --python "${VENV_DIR}/bin/python" /tmp/ai.lock \
    && uv pip check --python "${VENV_DIR}/bin/python" \
    && "${VENV_DIR}/bin/python" -c \
      'import diffusers, einops, huggingface_hub, timm, torch, torchvision' \
    && "${VENV_DIR}/bin/python" -c \
      'import sys; assert sys.version_info[:2] == (3, 12), sys.version' \
    && test "$(uv --version)" = 'uv 0.8.3' \
    && chown -R developer:developer "${VENV_DIR}"
WORKDIR /workspace
USER developer
