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

- API (FastAPI): `http://localhost:8000`
- MongoDB: Puerto `27017`
- RabbitMQ: `http://localhost:15672`
- Consumer (Worker)

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

## Despliegue en AWS con Terraform / OpenTofu
Cada vez que abres el lab de AWS las credenciales cambian y las EC2s anteriores ya no existen.
 
### 1. Obtener VPC, subnets y AZ
```bash
aws ec2 describe-subnets --query "Subnets[*].[SubnetId, VpcId, AvailabilityZone]" --output text
```
 
### 3. Actualizar terraform/variables.tf
- `vpc_id` y `subnet_id` con los valores del paso anterior
- `subnet_id_2` debe ser de una AZ distinta a `subnet_id`
- `key_name` con el nombre exacto de tu key pair en AWS
 
### 3. Inicializar y desplegar
 
**Con Terraform:**
```bash
cd terraform
terraform init
terraform plan -out=project.tfplan
terraform apply project.tfplan
terraform destroy
```
 
**Con OpenTofu:**
```bash
tofu init
tofu plan -out=project.tfplan
tofu apply project.tfplan
tofu destroy
```
 
### 4. Borrar todo
```bash
rm -rf .terraform .terraform.lock.hcl project.tfplan terraform.tfstate terraform.tfstate.backup
```
 
### 5. Aplicar un solo recurso
```bash
tofu apply -target=aws_instance.rabbitmq
tofu apply -target=aws_instance.api_server
tofu apply -target=aws_security_group.worker_sg
tofu apply -target=aws_ssm_parameter.worker_ip
```
 
### 6. 
# Ver solo el plan para un recurso individual
```bash
tofu plan -target=aws_instance.rabbitmq
```

# Aplicar solo a ese recurso
```bash
tofu apply -target=aws_instance.rabbitmq
```
 
### 7. Verificar que todo funcione
- HAProxy / API health check: `http://[IP_HAPROXY]/health`
- Swagger UI (interfaz gráfica): `http://[IP_HAPROXY]/docs`
- RabbitMQ UI: `http://[IP_RABBITMQ]:15672`
- MongoDB: agrega una nueva conection en MongoDB Compass. la URL pegar esto: `mongodb://admin:TU_PASSWORD@[IP_MONGO]:27017`
 
---

## Estructura del proyecto

```
.
├── api/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── scripts/
│   ├── install_api.sh
│   ├── install_haproxy.sh
│   ├── install_mongodb.sh
│   ├── install_postgres.sh
│   ├── install_rabbitmq.sh
│   └── install_worker.sh
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── security_groups.tf
│   └── variables.tf 
├── worker/
│   ├── consumer.py
│   └── get_parameter.py
├── .gitignore
├── docker-compose.yml
├── pyproject.toml
├── README.md
└── uv.lock
```

### ¿Qué hace cada archivo?
 
**api/main.py**
Contiene la definición de la API, endpoints GET, POST, PUT y DELETE, y conexión a MongoDB.
 
**api/Dockerfile**
Define cómo se construye la imagen de la API.
 
**worker/consumer.py**
Consumidor de mensajes RabbitMQ. Procesa eventos y los almacena en MongoDB.
 
**worker/get_parameter.py**
Consulta parámetros del AWS Parameter Store (SSM).
 
**scripts/**
Scripts de instalación para cada EC2 en AWS (user data de Terraform).
 
**terraform/**
Infraestructura como código — define las EC2s, security groups y parámetros SSM.
 
**docker-compose.yml**
Orquesta los servicios localmente: API, consumer, MongoDB y RabbitMQ.
 
**pyproject.toml**
Define las dependencias del proyecto y la configuración de mypy.
 
---

Crea un archivo `.env` en la raíz con:
 
```env
MONGO_URL=mongodb://admin:password123@mongodb:27017/
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=password123
MONGO_INITDB_DATABASE=finanzas
RABBITMQ_HOST=rabbitmq
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=password123
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_SESSION_TOKEN=your_token
AWS_DEFAULT_REGION=us-east-1
SSM_RABBITMQ_PARAM=/message-queue/dev/rabbitmq/public_ip
```

---

## Autores

- Santiago Henao Ramirez (git hub: shr-09)
- Juan Fernando Muñoz Lopez (git hub: juanferm0410)