from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from bson import ObjectId
from bson.errors import InvalidId
from datetime import date, datetime
import os

# api:
    # http://127.0.0.1:8000/docs
    # http://localhost:8000/docs

# rabbit:
    # http://localhost:15672

# get
    # http://localhost:8000/gastos

MONGO_URL = os.getenv("MONGO_URL", "mongodb://admin:password123@mongodb:27017/")
client = MongoClient(MONGO_URL)
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


# Convertir ObjectId a str
def serialize_doc(doc):
    doc["_id"] = str(doc["_id"])
    return doc


# Convertir date a datetime con hora 00:00:00 para que lo lea mongo para post y put
def convertir_fecha_gasto(gasto: Gasto):
    data = gasto.dict()
    data["fecha"] = datetime.combine(data["fecha"], datetime.min.time())
    return data


# Obtener todos los gastos
@app.get("/gastos")
def get_gastos():
    return [serialize_doc(doc) for doc in coleccion.find()]


# Crear un gasto
@app.post("/gastos")
def create_gasto(gasto: Gasto):
    data = convertir_fecha_gasto(gasto)
    result = coleccion.insert_one(data)
    return {"_id": str(result.inserted_id)}


# Actualizar un gasto por ID
@app.put("/gastos/{id}")
def update_gasto(id: str, gasto: Gasto):
    try:
        object_id = ObjectId(id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID inválido")

    data = convertir_fecha_gasto(gasto)

    result = coleccion.update_one(
        {"_id": object_id}, 
        {"$set": data}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Gasto no encontrado")

    return {"updated": result.modified_count}


# Eliminar un gasto por ID
@app.delete("/gastos/{id}")
def delete_gasto(id: str):
    result = coleccion.delete_one({"_id": ObjectId(id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Gasto no encontrado")
    return {"deleted": result.deleted_count}