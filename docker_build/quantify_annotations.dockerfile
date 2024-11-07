FROM python:3.12.7-slim

RUN pip install pandas
RUN pip install numpy

RUN mkdir /scripts/
COPY quantify_annotations.py /scripts/
COPY merge_quantified_annotations.py /scripts/

RUN apt-get update -y && \
    apt-get install -y procps

