#!/bin/bash
# Amazon Linux 2023 - Instalar dependencias para un Worker (Python)
set -e

sudo dnf update -y
sudo dnf install -y python3 python3-pip git

pip3 install pika celery requests pymongo boto3

# Clonar el repositorio
git clone https://github.com/shr-09/api-rabbitMQ-docker.git /home/ec2-user/app
chown -R ec2-user:ec2-user /home/ec2-user/app

# Ejecutar el consumer con las IPs inyectadas por Terraform
nohup bash -c '
  while true; do
    echo "[$(date)] Iniciando consumer..." >> /var/log/consumer.log
    MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/finanzas?authSource=admin" \
    RABBITMQ_HOST="${rabbitmq_ip}" \
    RABBITMQ_USER="admin" \
    RABBITMQ_PASSWORD="password123" \
    python3 /home/ec2-user/app/worker/consumer.py >> /var/log/consumer.log 2>&1
    echo "[$(date)] Consumer terminó, reiniciando en 10s..." >> /var/log/consumer.log
    sleep 10
  done
' &

echo "Worker iniciado. Logs en /var/log/consumer.log"
