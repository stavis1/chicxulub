FROM python:3.8.10-slim

RUN apt-get update -y && \
    apt-get install -y wget && \
    apt-get install -y gcc python3-dev 

RUN pip install eggnog-mapper
