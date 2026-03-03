# API de Gestión de Gastos 

API desarrollada con FastAPI para la gestión de gastos mensuales.
Permite crear, consultar, actualizar y eliminar gastos almacenados en MongoDB.
Incluye análisis estático con mypy y ejecución mediante Docker.

---

## Tecnologías utilizadas

- Python 3.11+
- FastAPI
- MongoDB
- RabbitMQ
- Docker & Docker Compose
- uv (gestor de dependencias)
- mypy (análisis estático de tipos)
- PyMongo
- Pydantic

---

## Funcionalidades de la API

### GET /gastos

Obtiene todos los gastos registrados.

**Respuesta:**
```json
[
  {
    "_id": "id_generado",
    "nombre": "Arriendo",
    "precio": 1200000,
    "fecha": "2026-03-01"
  }
]
```

###  POST /gastos

Crea un nuevo gasto.

**Body (JSON):**
```json
{
  "nombre": "Comida",
  "precio": 50000,
  "fecha": "2026-03-03"
}
```

###  PUT /gastos/{id}

Actualiza un gasto existente.

Permite modificar:
- nombre
- precio
- fecha

###  DELETE /gastos/{id}

Elimina un gasto por su ID.

---

##  Instalación y ejecución (modo local con uv)

### 1. Clonar el repositorio
```bash
git clone <URL_DEL_REPOSITORIO>
cd nombre-del-proyecto
```

### 2. Instalar dependencias

Este proyecto usa `uv` como gestor de paquetes.

```bash
uv sync
```

### 3. Ejecutar la API
```bash
uv run uvicorn main:app --reload
```

La API quedará disponible en: `http://localhost:8000`

Documentación automática: `http://localhost:8000/docs`

---

## Ejecución con Docker

### 1. Construir los contenedores
```bash
docker compose build
```

### 2. Levantar los servicios
```bash
docker compose up
```

Esto levantará:
- API (FastAPI)
- MongoDB
- RabbitMQ

### 3. Verificar que todo esté funcionando

- API: `http://localhost:8000`
- MongoDB: Puerto `27017`
- RabbitMQ: `http://localhost:15672`

---

## Análisis estático con mypy

Este proyecto incluye revisión estática de tipos.

```bash
uv run mypy .
```

Si todo está correcto, debería mostrar:

```
Success: no issues found
```

---

## Estructura del proyecto

```
.
├── main.py
├── consumer.py
├── pyproject.toml
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### 🔎 ¿Qué hace cada archivo?

**main.py**
Contiene la definición de la API, endpoints GET, POST, PUT y DELETE, y conexión a MongoDB.

**consumer.py**
Consumidor de mensajes RabbitMQ. Procesa eventos y los almacena en MongoDB.

**pyproject.toml**
Define las dependencias del proyecto y la configuración de mypy.

**Dockerfile**
Define cómo se construye la imagen de la API.

**docker-compose.yml**
Orquesta los servicios: API, MongoDB y RabbitMQ.

---

## Variables de entorno

```env
MONGO_URL=mongodb://admin:password123@mongodb:27017/
```

---

## Autor

- Santiago Henao Ramirez (git hub: shr-09)
- Juan Fernando Muñoz Lopez (git hub: juanferm0410)