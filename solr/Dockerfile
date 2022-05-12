FROM solr:8.11.1

USER solr

WORKDIR /opt/solr-8.11.1

COPY lib ./server/solr/configsets/archivesspace/conf
COPY schema.xml ./server/solr/configsets/archivesspace/conf
COPY solrconfig.xml ./server/solr/configsets/archivesspace/conf
COPY stopwords.txt ./server/solr/configsets/archivesspace/conf
COPY synonyms.txt ./server/solr/configsets/archivesspace/conf

RUN bin/solr start

RUN bin/solr create -c archivesspace -d archivesspace