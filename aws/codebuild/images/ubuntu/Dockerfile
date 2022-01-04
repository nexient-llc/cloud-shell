ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION} as base
ENV HOME /root

ENV ASDF_DEPS curl git unzip
RUN apt-get update && apt-get install -y ${ASDF_DEPS}

ENV ASDF_ROOT=${HOME}/.asdf
ARG ASDF_REPO=https://github.com/asdf-vm/asdf.git
RUN git clone ${ASDF_REPO} ${ASDF_ROOT} && cd ${ASDF_ROOT} && \
    git checkout "$(git describe --abbrev=0 --tags)" && cd -


FROM base as install

ENV PYTHON_DEPS build-essential zlib1g-dev libffi-dev libssl-dev libbz2-dev \
    tk-dev libxml2-dev libxmlsec1-dev liblzma-dev libreadline-dev libsqlite3-dev
RUN export DEBIAN_FRONTEND=noninteractive && apt-get install -y ${PYTHON_DEPS}

WORKDIR ${HOME}
COPY .tool-versions .
RUN ["/bin/bash", "-c", ". ${ASDF_ROOT}/asdf.sh && \
    asdf plugin add python && \
    asdf plugin add nodejs && \
    asdf plugin add java && \
    asdf install"]


FROM base as final

RUN apt-get install -y make jq zip wget gawk gnupg && \ 
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

# Copy the asdf directory from the previous image (install)
COPY --from=install ${ASDF_ROOT} ${ASDF_ROOT}
COPY --from=install ${HOME}/.tool-versions ${HOME}/.tool-versions

# Install AWS CLI
RUN ["/bin/bash", "-c", ". ${ASDF_ROOT}/asdf.sh && \
    pip install awscli && \
    asdf reshim"]
