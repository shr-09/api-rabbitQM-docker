#!/bin/bash
# Amazon Linux 2023 - Instalar dependencias para un Worker (Python)
sudo dnf update -y
sudo dnf install -y python3 python3-pip git

# Se instalan algunas librerías genéricas si es necesario
pip3 install pika celery requests pymongo boto3

# Crear directorio del worker
mkdir -p /home/ec2-user/worker
cd /home/ec2-user/worker
 
# Crear consumer.py
cat <<'EOF' > consumer.py
import pika
import json
import time
import os
from pymongo import MongoClient

MONGO_URL = os.getenv("MONGO_URL", "mongodb://admin:password123@mongodb:27017/")
RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "password123")

mongo = MongoClient(MONGO_URL)   # type: ignore
db = mongo["finanzas"]
coleccion = db["gastos"]

def callback(ch, method, properties, body):
    try:
        data = json.loads(body)
        print("Insertando en Mongo:", data)
        coleccion.insert_one(data)
    except Exception as e:
        print("Error procesando mensaje:", e)

def start_consumer():
    while True:
        try:
            credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(
                    host=RABBITMQ_HOST,
                    credentials=credentials
                )
            )
            break
        except pika.exceptions.AMQPConnectionError:
            print("Esperando a RabbitMQ...")
            time.sleep(5)

    channel = connection.channel()
    channel.queue_declare(queue="gastos")

    channel.basic_consume(
        queue="gastos",
        on_message_callback=callback,
        auto_ack=True
    )

    print("Consumer listo. Esperando mensajes...")
    channel.start_consuming()


if __name__ == "__main__":
    start_consumer()
EOF
 
# Crear get_parameter.py
cat <<'EOF' > get_parameter.py
import boto3
import os
from botocore.exceptions import ClientError
 
def get_ssm_parameter(name: str, default: str = None) -> str:
    """
    Consulta un parámetro del Parameter Store de AWS.
    Si no existe, retorna el valor default.
    """
    region = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("ssm", region_name=region)
    try:
        response = client.get_parameter(Name=name)
        return response["Parameter"]["Value"]
    except ClientError as e:
        if e.response["Error"]["Code"] == "ParameterNotFound":
            print(f"[WARN] Parámetro '{name}' no encontrado. Usando valor por defecto: '{default}'")
            return default
        raise
 
if __name__ == "__main__":
    rabbitmq_ip = get_ssm_parameter(
        name=os.getenv("SSM_RABBITMQ_PARAM", "/message-queue/dev/rabbitmq/public_ip"),
        default="localhost"
    )
    print(f"RabbitMQ IP: {rabbitmq_ip}")
EOF
 
# Asignar permisos
chown -R ec2-user:ec2-user /home/ec2-user/worker
 
# Ejecutar el consumer con las IPs inyectadas por Terraform
MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/" \
RABBITMQ_HOST="${rabbitmq_ip}" \
nohup python3 /home/ec2-user/worker/consumer.py > /var/log/consumer.log 2>&1 &
 