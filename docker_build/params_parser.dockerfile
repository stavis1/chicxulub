FROM python:3.11.9-slim

RUN mkdir /parser/
RUN pip install tomli-w
COPY options_parser.py /parser/
