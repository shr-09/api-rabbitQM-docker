#!/bin/bash
# Amazon Linux 2023 - Instalar Docker
sudo dnf update -y
sudo dnf install -y docker git

# Instalar Docker Compose (recomendado)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Añadir al usuario ec2-user al grupo docker
sudo usermod -aG docker ec2-user

# --- Despliegue de la API FastAPI ---

# Crear directorio para la API
mkdir -p /home/ec2-user/api
cd /home/ec2-user/api

# Crear main.py
cat <<EOF > main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from bson import ObjectId
from bson.errors import InvalidId
from datetime import date, datetime
import os
import boto3
from botocore.exceptions import ClientError
 
MONGO_URL = os.getenv("MONGO_URL", "mongodb://admin:password123@mongodb:27017/")
 
client = MongoClient(MONGO_URL) # type: ignore
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
 
def convertir_fecha_gasto(gasto: Gasto):
    data = gasto.dict()
    data["fecha"] = datetime.combine(data["fecha"], datetime.min.time())
    return data
 
@app.get("/health")
def health_check():
    return {"status": "healthy"}
 
@app.get("/gastos")
def get_gastos():
    return [serialize_doc(doc) for doc in coleccion.find()]
 
@app.post("/gastos")
def create_gasto(gasto: Gasto):
    data = convertir_fecha_gasto(gasto)
    result = coleccion.insert_one(data)
    return {"_id": str(result.inserted_id)}
 
@app.put("/gastos/{id}")
def update_gasto(id: str, gasto: Gasto):
    try:
        object_id = ObjectId(id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID inválido")
    data = convertir_fecha_gasto(gasto)
    result = coleccion.update_one({"_id": object_id}, {"$set": data})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Gasto no encontrado")
    return {"updated": result.modified_count}
 
@app.delete("/gastos/{id}")
def delete_gasto(id: str):
    result = coleccion.delete_one({"_id": ObjectId(id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Gasto no encontrado")
    return {"deleted": result.deleted_count}
EOF

# Crear requirements.txt
cat <<EOF > requirements.txt
fastapi
pydantic
pymongo
uvicorn
pika
boto3
EOF

# Crear Dockerfile
cat <<EOF > Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Construir y ejecutar el contenedor
sudo docker build -t simple-api .
sudo docker run -d --restart=always --name fast-api -p 80:8000 \
  -e MONGO_URL="mongodb://admin:password123@${mongodb_ip}:27017/" \
  simple-api