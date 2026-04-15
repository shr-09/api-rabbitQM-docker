#!/bin/bash
set -e

# Amazon Linux 2023 - Instalar Docker
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

# --- Despliegue de la API FastAPI ---
mkdir -p /home/ec2-user/api
cd /home/ec2-user/api

# NOTA: se usan comillas dobles en <<EOF para que ${mongodb_ip} y ${rabbitmq_ip}
# sean expandidas por Terraform/bash al momento de generar el script.
cat <<'PYEOF' > main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from bson import ObjectId
from bson.errors import InvalidId
from datetime import date, datetime
import os
import json
import pika

MONGO_URL       = os.getenv("MONGO_URL",         "mongodb://admin:password123@localhost:27017/finanzas?authSource=admin")
RABBITMQ_HOST   = os.getenv("RABBITMQ_HOST",     "localhost")
RABBITMQ_USER   = os.getenv("RABBITMQ_USER",     "admin")
RABBITMQ_PASS   = os.getenv("RABBITMQ_PASSWORD", "password123")

# Mongo solo para GET y DELETE
client = MongoClient(MONGO_URL)
db = client["finanzas"]
coleccion = db["gastos"]

app = FastAPI(title="API Control de Gastos Hormiga")

class Gasto(BaseModel):
    item: str
    costo: float
    categoria: str
    fecha: date

def serialize_doc(doc):
    doc["_id"] = str(doc["_id"])
    return doc

def convertir_fecha_gasto(gasto: Gasto) -> dict:
    data = gasto.dict()
    data["fecha"] = datetime.combine(data["fecha"], datetime.min.time())
    return data

def get_rabbit_channel():
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    channel.queue_declare(queue="gastos", durable=True)
    return connection, channel

def publicar_en_cola(data: dict):
    connection, channel = get_rabbit_channel()
    channel.basic_publish(
        exchange="",
        routing_key="gastos",
        body=json.dumps(data, default=str),
        properties=pika.BasicProperties(delivery_mode=2),
    )
    connection.close()

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/gastos")
def get_gastos():
    return [serialize_doc(doc) for doc in coleccion.find()]

@app.post("/gastos", status_code=202)
def create_gasto(gasto: Gasto):
    data = convertir_fecha_gasto(gasto)
    data["accion"] = "insert"
    publicar_en_cola(data)
    return {"queued": True, "mensaje": "Gasto enviado a la cola para procesamiento"}

@app.put("/gastos/{id}", status_code=202)
def update_gasto(id: str, gasto: Gasto):
    try:
        ObjectId(id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID inválido")
    data = convertir_fecha_gasto(gasto)
    data["accion"] = "update"
    data["id"] = id
    publicar_en_cola(data)
    return {"queued": True, "mensaje": f"Actualización del gasto {id} enviada a la cola"}

@app.delete("/gastos/{id}")
def delete_gasto(id: str):
    try:
        object_id = ObjectId(id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID inválido")
    result = coleccion.delete_one({"_id": object_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Gasto no encontrado")
    return {"deleted": result.deleted_count}
PYEOF

cat <<'EOF' > requirements.txt
fastapi
pydantic
pymongo
uvicorn
pika
boto3
EOF

cat <<'EOF' > Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Construir imagen y levantar contenedor con las IPs de Terraform
sudo docker build -t simple-api .
sudo docker run -d --restart=always --name fast-api -p 80:8000 \
  -e MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/finanzas?authSource=admin" \
  -e RABBITMQ_HOST="${rabbitmq_ip}" \
  -e RABBITMQ_USER="admin" \
  -e RABBITMQ_PASSWORD="password123" \
  simple-api
