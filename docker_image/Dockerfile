ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION} as base
ENV HOME /root

ENV ASDF_DEPS curl git unzip
RUN apt-get update && apt-get install -y ${ASDF_DEPS}

ENV ASDF_ROOT=${HOME}/.asdf
ARG ASDF_REPO=https://github.com/asdf-vm/asdf.git
RUN git clone ${ASDF_REPO} ${ASDF_ROOT} && cd ${ASDF_ROOT} &&\
    git checkout "$(git describe --abbrev=0 --tags)" && cd -


FROM base as install

ENV PYTHON_DEPS build-essential zlib1g-dev libffi-dev libssl-dev libbz2-dev \
    tk-dev libxml2-dev libxmlsec1-dev liblzma-dev libreadline-dev libsqlite3-dev
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y ${PYTHON_DEPS}

SHELL ["/bin/bash", "-c"]
WORKDIR ${HOME}

COPY .tool-versions .
RUN . ${ASDF_ROOT}/asdf.sh && \
    asdf plugin add python && \
    asdf plugin add nodejs && \
    asdf install && \
    pip install awscli && \
    npm install -g serverless --unsafe-perm && \
    asdf reshim

FROM base as final

WORKDIR ${HOME}
ENV TZ America/New_York

RUN apt-get install -y make jq zip wget gawk gnupg && \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
# Copy the asdf directory from the previous image - install
COPY --from=install ${ASDF_ROOT} ${ASDF_ROOT}
COPY .tool-versions .
# Source the asdf in .bashrc
SHELL ["/bin/bash", "-c"]
RUN apt-get install -y tzdata && \
    echo ". ${ASDF_ROOT}/asdf.sh" >> ${HOME}/.bashrc && \
    echo "export PATH=$PATH:${ASDF_ROOT}/bin" >> /etc/environment
