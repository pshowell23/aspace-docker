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
    nano \
    unzip
RUN wget -q https://github.com/archivesspace/archivesspace/releases/download/v3.2.0/archivesspace-v3.2.0.zip && \
    unzip archivesspace-v3.2.0.zip && \
    rm archivesspace-v3.2.0.zip
RUN wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar && \
    mv mysql-connector-java-8.0.28.jar /archivesspace/lib/
COPY ./configuration/en.yml /archivesspace/locales/public/
COPY ./docker-startup.sh /archivesspace/startup.sh
RUN chmod u+x /archivesspace/startup.sh && \
    groupadd -g 1000 archivesspace && \
    useradd -l -M -u 1000 -g archivesspace archivesspace && \
    chown -R archivesspace:archivesspace /archivesspace
USER archivesspace
CMD [ "archivesspace/startup.sh" ]