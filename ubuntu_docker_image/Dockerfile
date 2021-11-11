FROM ubuntu:20.04
ENV TZ America/New_York
RUN apt-get update && apt-get install -y make jq zip wget gawk gnupg && \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
RUN apt-get install -y tzdata ca-certificates curl git unzip
