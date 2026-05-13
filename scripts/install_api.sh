#!/bin/bash
# Amazon Linux 2023 - Instalar Docker y desplegar la API FastAPI
set -e

sudo dnf update -y
sudo dnf install -y docker git

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Añadir al usuario ec2-user al grupo docker
sudo usermod -aG docker ec2-user

# Clonar el repositorio
git clone https://github.com/shr-09/api-rabbitMQ-docker.git /home/ec2-user/app
chown -R ec2-user:ec2-user /home/ec2-user/app

# Construir imagen y levantar contenedor con las IPs de Terraform
sudo docker build -t simple-api -f /home/ec2-user/app/api/Dockerfile /home/ec2-user/app # -f le dice la ruta exacta donde este el Dockerfile
sudo docker run -d --restart=always --name fast-api -p 80:8000 \
  -e MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/finanzas?authSource=admin" \
  -e RABBITMQ_HOST="${rabbitmq_ip}" \
  -e RABBITMQ_USER="admin" \
  -e RABBITMQ_PASSWORD="password123" \
  simple-api
