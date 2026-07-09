# Stage 1: Compile Java files inside the Kafka image so Kafka's JARs are on the classpath.
# AllowAllCallbackHandler needs kafka-clients.jar (PlainAuthenticateCallback) at compile time.
FROM apache/kafka:3.9.0 AS builder
USER root
WORKDIR /build
COPY AllowAllLoginModule.java AllowAllCallbackHandler.java ./
RUN javac AllowAllLoginModule.java && \
    javac -cp "/opt/kafka/libs/*" AllowAllCallbackHandler.java && \
    jar cf allowall.jar AllowAllLoginModule.class AllowAllCallbackHandler.class

# Stage 2: Install JAR + startup script
FROM apache/kafka:3.9.0
USER root
COPY --from=builder /build/allowall.jar /opt/kafka/libs/allowall.jar
COPY --chmod=755 kafka-startup.sh /opt/kafka/bin/kafka-startup.sh
USER appuser
