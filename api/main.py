from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from bson import ObjectId
from bson.errors import InvalidId
from datetime import date, datetime
import os
import json
import pika

# api:
    # http://127.0.0.1:8000/docs
    # http://localhost:8000/docs

# rabbit:
    # http://localhost:15672

# get
    # http://localhost:8000/gastos

MONGO_URL       = os.getenv("MONGO_URL",         "mongodb://admin:password123@mongodb:27017/")
RABBITMQ_HOST   = os.getenv("RABBITMQ_HOST",     "rabbitmq")
RABBITMQ_USER   = os.getenv("RABBITMQ_USER",     "admin")
RABBITMQ_PASS   = os.getenv("RABBITMQ_PASSWORD", "password123")

# Conexión MongoDb (solo para GET y DELETE, que no pasan por la cola)
client = MongoClient(MONGO_URL)  # type: ignore
db = client["finanzas"]
coleccion = db["gastos"]

# FastAPI
app = FastAPI(title="API Control de Gastos Hormiga")

# Modelo de datos
class Gasto(BaseModel):
    item: str        # Ej: "Café"
    costo: float     # Ej: 4500
    categoria: str   # Ej: "Comida"
    fecha: date      # Ej: "2024-05-20"


# ---------- helpers ----------

def serialize_doc(doc):
    doc["_id"] = str(doc["_id"])
    return doc


def convertir_fecha_gasto(gasto: Gasto) -> dict:
    """Convierte date a datetime para que MongoDB lo acepte."""
    data = gasto.dict()
    data["fecha"] = datetime.combine(data["fecha"], datetime.min.time())
    return data


def get_rabbit_channel():
    """Abre una conexión+canal a RabbitMQ y declara la cola."""
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    channel.queue_declare(queue="gastos", durable=True)
    return connection, channel


def publicar_en_cola(data: dict):
    """
    Serializa `data` a JSON y lo publica en la cola 'gastos'.
    El campo `fecha` (datetime) se convierte a string ISO-8601.
    """
    connection, channel = get_rabbit_channel()
    channel.basic_publish(
        exchange="",
        routing_key="gastos",
        body=json.dumps(data, default=str),   # default=str maneja datetime
        properties=pika.BasicProperties(
            delivery_mode=2,  # mensaje persistente (sobrevive reinicios)
        ),
    )
    connection.close()


# ---------- endpoints ----------

@app.get("/health")
def health_check():
    return {"status": "healthy"}


# Obtener todos los gastos (lee directo de Mongo)
@app.get("/gastos")
def get_gastos():
    return [serialize_doc(doc) for doc in coleccion.find()]


# Crear un gasto → publica en RabbitMQ; el consumer lo inserta en Mongo
@app.post("/gastos", status_code=202)
def create_gasto(gasto: Gasto):
    data = convertir_fecha_gasto(gasto)
    data["accion"] = "insert"          # el consumer usará esto para saber qué hacer
    publicar_en_cola(data)
    return {"queued": True, "mensaje": "Gasto enviado a la cola para procesamiento"}


# Actualizar un gasto → publica en RabbitMQ; el consumer ejecuta el update
@app.put("/gastos/{id}", status_code=202)
def update_gasto(id: str, gasto: Gasto):
    try:
        ObjectId(id)                   # solo validamos el formato del ID
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID inválido")

    data = convertir_fecha_gasto(gasto)
    data["accion"] = "update"
    data["id"] = id
    publicar_en_cola(data)
    return {"queued": True, "mensaje": f"Actualización del gasto {id} enviada a la cola"}


# Eliminar un gasto por ID (operación directa, sin cola)
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
