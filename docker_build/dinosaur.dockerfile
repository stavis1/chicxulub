FROM maven:3.9.10-amazoncorretto-8-debian AS maven
#build most recent version of Dinosaur
RUN apt-get update -y && \
    apt-get install -y git
RUN git clone https://github.com/fickludd/dinosaur && \
    cd dinosaur && \
    mvn install


FROM eclipse-temurin:8u422-b05-jre-noble
RUN apt-get update -y && \
    apt-get install -y procps && \
    mkdir /dinosaur

COPY --from=maven /dinosaur/target/Dinosaur-1.2.1.free.jar /dinosaur/Dinosaur.jar


