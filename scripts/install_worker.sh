#!/bin/bash
# Amazon Linux 2023 - Instalar dependencias para un Worker (Python)
set -e

sudo dnf update -y
sudo dnf install -y python3 python3-pip git

pip3 install pika celery requests pymongo boto3

# Crear directorio del worker
mkdir -p /home/ec2-user/worker
cd /home/ec2-user/worker

# NOTA: heredoc con comillas simples ('EOF') → el contenido se escribe literal,
# sin expansión de shell. Las IPs reales se inyectan más abajo vía variables
# de entorno en el comando nohup.
cat <<'EOF' > consumer.py
import pika
import json
import time
import os
from pymongo import MongoClient
from bson import ObjectId

MONGO_URL         = os.getenv("MONGO_URL",         "mongodb://admin:password123@localhost:27017/finanzas?authSource=admin")
RABBITMQ_HOST     = os.getenv("RABBITMQ_HOST",     "localhost")
RABBITMQ_USER     = os.getenv("RABBITMQ_USER",     "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "password123")


def get_coleccion():
    mongo = MongoClient(MONGO_URL)   # type: ignore
    db = mongo["finanzas"]
    return db["gastos"]


def callback(ch, method, properties, body):
    try:
        data = json.loads(body)
        coleccion = get_coleccion()
        accion = data.pop("accion", "insert")

        if accion == "insert":
            print(f"[INSERT] Insertando en Mongo: {data}")
            coleccion.insert_one(data)

        elif accion == "update":
            doc_id = data.pop("id")
            print(f"[UPDATE] Actualizando gasto {doc_id}: {data}")
            result = coleccion.update_one(
                {"_id": ObjectId(doc_id)},
                {"$set": data}
            )
            if result.matched_count == 0:
                print(f"[WARN] Gasto {doc_id} no encontrado para actualizar")

        else:
            print(f"[WARN] Acción desconocida '{accion}', mensaje descartado")

        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as e:
        print(f"[ERROR] Procesando mensaje: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def start_consumer():
    while True:
        try:
            credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(
                    host=RABBITMQ_HOST,
                    credentials=credentials,
                    heartbeat=600,
                    blocked_connection_timeout=300,
                )
            )
            break
        except pika.exceptions.AMQPConnectionError:
            print("[INFO] Esperando a RabbitMQ...")
            time.sleep(5)

    channel = connection.channel()
    channel.queue_declare(queue="gastos", durable=True)
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(
        queue="gastos",
        on_message_callback=callback,
        auto_ack=False,
    )

    print("[INFO] Consumer listo. Esperando mensajes...")
    channel.start_consuming()


if __name__ == "__main__":
    start_consumer()
EOF

cat <<'EOF' > get_parameter.py
import boto3
import os
from botocore.exceptions import ClientError
from typing import Optional

def get_ssm_parameter(name: str, default: Optional[str] = None) -> Optional[str]:
    """
    Consulta un parámetro del Parameter Store de AWS.
    Si no existe, retorna el valor `default`.
    """
    region = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("ssm", region_name=region)
    try:
        response = client.get_parameter(Name=name)
        return str(response["Parameter"]["Value"])
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

chown -R ec2-user:ec2-user /home/ec2-user/worker

# Ejecutar el consumer con las IPs inyectadas por Terraform
nohup bash -c '
  while true; do
    echo "[$(date)] Iniciando consumer..." >> /var/log/consumer.log
    MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/finanzas?authSource=admin" \
    RABBITMQ_HOST="${rabbitmq_ip}" \
    RABBITMQ_USER="admin" \
    RABBITMQ_PASSWORD="password123" \
    python3 /home/ec2-user/worker/consumer.py >> /var/log/consumer.log 2>&1
    echo "[$(date)] Consumer terminó, reiniciando en 10s..." >> /var/log/consumer.log
    sleep 10
  done
' &

echo "Worker iniciado. Logs en /var/log/consumer.log"
