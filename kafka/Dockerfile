# Stage 1: Compile AllowAllLoginModule using JDK
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /build
COPY AllowAllLoginModule.java .
RUN javac AllowAllLoginModule.java && \
    jar cf allowall.jar AllowAllLoginModule.class

# Stage 2: Add compiled JAR + startup script into the Kafka image
FROM apache/kafka:3.9.0
USER root
COPY --from=builder /build/allowall.jar /opt/kafka/libs/allowall.jar
COPY --chmod=755 kafka-startup.sh /opt/kafka/bin/kafka-startup.sh
USER appuser
