#!/bin/bash
# Dev-only startup: generate self-signed SSL certs then hand off to KafkaDockerWrapper.
set -e

echo "=== Kafka Dev Startup (SASL_SSL) ==="

PASS=kafkadev
HOST="${KAFKA_HOST_IP:-127.0.0.1}"
SSL_DIR=/tmp/kafka-ssl
rm -rf "$SSL_DIR"
mkdir -p "$SSL_DIR"
cd "$SSL_DIR"

echo "Generating SSL certificates for $HOST ..."

# CA key + self-signed cert (must be a proper CA: basicConstraints + keyCertSign)
keytool -genkeypair -keyalg RSA -keysize 2048 -validity 3650 \
  -alias ca -keystore ca.jks -storetype JKS \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=KafkaDevCA,OU=Dev,O=Dev,L=Dev,ST=Dev,C=US" \
  -ext "BC:critical=ca:true" \
  -ext "KU:critical=keyCertSign,CRLSign" \
  -noprompt 2>/dev/null

keytool -exportcert -keystore ca.jks -alias ca \
  -storepass "$PASS" -file ca.crt 2>/dev/null

# Broker key + cert signed by CA (SAN covers the VM internal IP)
keytool -genkeypair -keyalg RSA -keysize 2048 -validity 3650 \
  -alias broker -keystore broker.jks -storetype JKS \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=$HOST,OU=Dev,O=Dev,L=Dev,ST=Dev,C=US" \
  -ext "SAN=IP:$HOST,IP:127.0.0.1" -noprompt 2>/dev/null

keytool -certreq -keystore broker.jks -alias broker \
  -storepass "$PASS" -file broker.csr 2>/dev/null

keytool -gencert -keystore ca.jks -alias ca \
  -storepass "$PASS" \
  -ext "SAN=IP:$HOST,IP:127.0.0.1" \
  -ext "EKU=serverAuth,clientAuth" \
  -infile broker.csr -outfile broker.crt -validity 3650 2>/dev/null

keytool -importcert -keystore broker.jks -storepass "$PASS" \
  -noprompt -alias ca -file ca.crt 2>/dev/null
keytool -importcert -keystore broker.jks -storepass "$PASS" \
  -noprompt -alias broker -file broker.crt 2>/dev/null

# Truststore with just the CA
keytool -importcert -keystore truststore.jks -storetype JKS \
  -storepass "$PASS" -noprompt -alias ca -file ca.crt 2>/dev/null

echo "SSL certificates ready."
echo "Starting Kafka ..."
exec /etc/kafka/docker/run
