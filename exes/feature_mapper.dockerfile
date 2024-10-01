FROM python:3.11.9-slim

RUN mkdir /mapper
COPY options_parser.py /mapper/
COPY feature_mapper.py /mapper/

COPY requirements.txt /
RUN pip install -r /requirements.txt

