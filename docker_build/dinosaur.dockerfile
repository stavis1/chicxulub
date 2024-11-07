FROM eclipse-temurin:8u422-b05-jre-noble

RUN apt-get update -y && \
    apt-get install -y wget && \
    apt-get install procps && \
    mkdir /dinosaur && \
    cd dinosaur && \
    wget https://github.com/fickludd/dinosaur/releases/download/1.2.0/Dinosaur-1.2.0.free.jar -O Dinosaur.jar
