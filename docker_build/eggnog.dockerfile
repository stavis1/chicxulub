FROM python:3.8.10-slim

RUN apt-get update -y && \
    apt-get install -y wget && \
    apt-get install procps && \
    apt-get install -y gcc python3-dev 
RUN mkdir /cache/

RUN pip install eggnog-mapper
RUN pip install tomli

COPY eggnog_wrapper.py /usr/local/bin/
