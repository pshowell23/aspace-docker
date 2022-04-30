FROM solr:8.10

WORKDIR /opt/solr/server/solr/archivesspace

RUN mkdir conf && \
    mkdir data && \
    wget -q https://github.com/archivesspace/archivesspace/releases/download/v3.2.0/archivesspace-v3.2.0.zip && \
    unzip archivesspace-v3.2.0.zip && \
    rm archivesspace-v3.2.0.zip && \
    mv archivesspace/solr/ conf/ && \
    rm -rf archivesspace

USER solr