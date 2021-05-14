FROM ubuntu:18.04


RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get -y install --no-install-recommends \
    build-essential \
    git \
    openjdk-8-jre-headless \
    openjdk-8-jdk \
    ca-certificates \
    wget \
    openssh-server \
    vim \
    unzip

RUN mkdir /aspace && \
    cd /aspace && \
    wget -q https://github.com/archivesspace/archivesspace/releases/download/v2.8.1/archivesspace-v2.8.1.zip && \
    unzip archivesspace-v2.8.1.zip && \
    rm archivesspace-v2.8.1.zip

RUN /aspace/archivesspace/scripts/setup-database.sh

EXPOSE 8080 8081 8089 8090 8092

CMD [ "/aspace/archivesspace/archivesspace.sh" ]