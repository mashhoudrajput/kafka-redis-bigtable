# Pull Kafka libs so AllowAllCallbackHandler can reference PlainAuthenticateCallback at compile time
FROM apache/kafka:3.9.0 AS kafka-libs

# Stage 1: Compile using a JDK, with Kafka libs on the classpath
FROM eclipse-temurin:21-jdk AS builder
COPY --from=kafka-libs /opt/kafka/libs /kafka-libs
WORKDIR /build
COPY AllowAllLoginModule.java AllowAllCallbackHandler.java ./
RUN javac AllowAllLoginModule.java && \
    javac -cp "/kafka-libs/*" AllowAllCallbackHandler.java && \
    jar cf allowall.jar AllowAllLoginModule.class AllowAllCallbackHandler.class

# Stage 2: Install JAR + startup script
FROM apache/kafka:3.9.0
USER root
COPY --from=builder /build/allowall.jar /opt/kafka/libs/allowall.jar
COPY --chmod=755 kafka-startup.sh /opt/kafka/bin/kafka-startup.sh
USER appuser
