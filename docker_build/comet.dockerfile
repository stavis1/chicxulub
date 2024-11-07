FROM ubuntu:24.04

RUN apt-get update -y && \
    apt-get install -y wget && \
    apt-get install -y procps

RUN mkdir /comet/ && \
    cd /comet/ && \
    wget https://github.com/UWPR/Comet/releases/download/v2024.02.0/comet.linux.exe && \
    chmod +x comet.linux.exe


