FROM python:3.11.9-slim

RUN mkdir /parser/
COPY options_parser.py /parser/
