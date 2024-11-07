FROM python:3.11.9-slim

RUN mkdir /mapper
COPY feature_mapper.py /mapper/

RUN apt-get update -y && \
    apt-get install -y procps

COPY requirements.txt /
RUN pip install -r /requirements.txt

