from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from bson import ObjectId

#http://127.0.0.1:8000/docs

import os

MONGO_URL = os.getenv("MONGO_URL", "mongodb://admin:password123@mongodb:27017/")
client = MongoClient(MONGO_URL)
db = client["universidad"]
coleccion = db["estudiantes"]

# FastAPI
app = FastAPI(title="API Estudiantes")

# Modelo de datos
class Estudiante(BaseModel):
    nombre: str
    carrera: str
    semestre: int

# Convertir ObjectId a str
def serialize_doc(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@app.get("/estudiantes")
def get_estudiantes():
    return [serialize_doc(doc) for doc in coleccion.find()]

@app.post("/estudiantes")
def create_estudiante(estudiante: Estudiante):
    result = coleccion.insert_one(estudiante.dict())
    return {"_id": str(result.inserted_id)}

# Actualizar un estudiante por ID
@app.put("/estudiantes/{id}")
def update_estudiante(id: str, estudiante: Estudiante):
    result = coleccion.update_one({"_id": ObjectId(id)}, {"$set": estudiante.dict()})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado")
    return {"updated": result.modified_count}

# Eliminar un estudiante por ID
@app.delete("/estudiantes/{id}")
def delete_estudiante(id: str):
    result = coleccion.delete_one({"_id": ObjectId(id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado")
    return {"deleted": result.deleted_count}