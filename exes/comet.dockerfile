FROM ubuntu:24.04

RUN apt-get update -y && \
    apt-get install -y wget

RUN mkdir /comet/ && \
    cd /comet/ && \
    wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe && \
    chmod +x comet.linux.exe


