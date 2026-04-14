#!/bin/bash
# Amazon Linux 2023 - Instalar Docker y RabbitMQ via Docker Compose

set -e  # detiene el script si algo falla (para ver el error en logs)

# 1. Update system and install Docker
sudo dnf update -y 
sudo dnf install -y docker

# 2. Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 3. Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker
sleep 10  # esperar que Docker arranque completamente
sudo usermod -aG docker ec2-user

# 4. Create directory for RabbitMQ
mkdir -p /home/ec2-user/rabbitmq
cd /home/ec2-user/rabbitmq

# 5. Create docker-compose.yml
cat << 'EOF' > /home/ec2-user/rabbitmq/docker-compose.yml
services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq_server
    restart: always
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: password123
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF

# Asignar permisos al usuario ec2-user
chown -R ec2-user:ec2-user /home/ec2-user/rabbitmq

# 6. Start RabbitMQ container
sudo docker-compose up -d
