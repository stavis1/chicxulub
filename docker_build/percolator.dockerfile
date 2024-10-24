FROM ubuntu:24.04

RUN apt-get update -y && \
    apt-get install -y wget && \
    apt-get install -y libgomp1

RUN wget https://github.com/percolator/percolator/releases/download/rel-3-06-05/percolator-noxml-v3-06-linux-amd64.deb && \
    apt-get install -y /percolator-noxml-v3-06-linux-amd64.deb

RUN mkdir /data/
