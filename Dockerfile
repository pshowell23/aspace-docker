FROM ubuntu:18.04
EXPOSE 8080 8081
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
RUN wget -q https://github.com/archivesspace/archivesspace/releases/download/v2.8.1/archivesspace-v2.8.1.zip && \
    unzip archivesspace-v2.8.1.zip && \
    rm archivesspace-v2.8.1.zip
COPY ./configuration/config.rb /archivesspace/config/
COPY ./configuration/en.yml /archivesspace/locales/public/
RUN archivesspace/scripts/setup-database.sh
CMD [ "archivesspace/archivesspace.sh" ]