import pytest
from fastapi.testclient import TestClient
from pymongo import MongoClient
import sys
import os

# Agregar la carpeta raíz del proyecto al path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from api.main import app

# Base de datos de prueba
MONGO_URL = "mongodb://admin:password123@localhost:27017/"
mongo_client: MongoClient = MongoClient(MONGO_URL)
db_test = mongo_client["finanzas_test"]
coleccion_test = db_test["gastos"]

# Cliente de pruebas
client_app = TestClient(app)

# Fixture para limpiar la colección antes y después de cada test
@pytest.fixture(autouse=True)
def limpiar_db():
    coleccion_test.delete_many({})
    yield
    coleccion_test.delete_many({})

def test_post_gasto():
    response = client_app.post("/gastos", json={
        "item": "Café",
        "costo": 4500,
        "categoria": "Comida",
        "fecha": "2026-03-03"
    })
    assert response.status_code == 200
    data = response.json()
    assert "_id" in data

def test_get_gastos():
    coleccion_test.insert_one({
        "item": "Snack",
        "costo": 3000,
        "categoria": "Comida",
        "fecha": "2026-03-02"
    })
    response = client_app.get("/gastos")
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["item"] == "Snack"

def test_put_gasto():
    result = coleccion_test.insert_one({
        "item": "Agua",
        "costo": 2000,
        "categoria": "Bebida",
        "fecha": "2026-03-01"
    })
    id_gasto = str(result.inserted_id)
    response = client_app.put(f"/gastos/{id_gasto}", json={
        "item": "Agua Mineral",
        "costo": 2500,
        "categoria": "Bebida",
        "fecha": "2026-03-01"
    })
    assert response.status_code == 200
    assert response.json()["updated"] == 1

def test_delete_gasto():
    result = coleccion_test.insert_one({
        "item": "Jugo",
        "costo": 3000,
        "categoria": "Bebida",
        "fecha": "2026-03-01"
    })
    id_gasto = str(result.inserted_id)
    response = client_app.delete(f"/gastos/{id_gasto}")
    assert response.status_code == 200
    assert response.json()["deleted"] == 1