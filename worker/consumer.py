import pika
import json
import time
import os
from pymongo import MongoClient
from bson import ObjectId

MONGO_URL        = os.getenv("MONGO_URL",         "mongodb://admin:password123@mongodb:27017/")
RABBITMQ_HOST    = os.getenv("RABBITMQ_HOST",     "rabbitmq")
RABBITMQ_USER    = os.getenv("RABBITMQ_USER",     "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "password123")


def get_coleccion():
    """Crea la conexión a Mongo en el momento de usarla (no al importar el módulo)."""
    mongo = MongoClient(MONGO_URL)  # type: ignore
    db = mongo["finanzas"]
    return db["gastos"]


def callback(ch, method, properties, body):
    """
    Procesa cada mensaje de la cola.
    Soporta dos acciones:
      - "insert": inserta un documento nuevo en Mongo.
      - "update": actualiza un documento existente por su _id.
    Si no hay campo 'accion' se asume "insert" para compatibilidad con
    mensajes legacy.
    """
    try:
        data = json.loads(body)
        coleccion = get_coleccion()
        accion = data.pop("accion", "insert")   # extrae y elimina el campo auxiliar

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

        # ACK manual: solo confirmamos si todo salió bien
        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as e:
        print(f"[ERROR] Procesando mensaje: {e}")
        # NACK sin requeue para no entrar en bucle infinito
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def start_consumer():
    # Esperar hasta que RabbitMQ esté listo
    while True:
        try:
            credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(
                    host=RABBITMQ_HOST,
                    credentials=credentials,
                    heartbeat=600,               # evita que la conexión se cierre en idle
                    blocked_connection_timeout=300,
                )
            )
            break
        except pika.exceptions.AMQPConnectionError:
            print("[INFO] Esperando a RabbitMQ...")
            time.sleep(5)

    channel = connection.channel()

    # durable=True: la cola sobrevive reinicios de RabbitMQ
    channel.queue_declare(queue="gastos", durable=True)

    # prefetch_count=1: procesa un mensaje a la vez (fair dispatch)
    channel.basic_qos(prefetch_count=1)

    channel.basic_consume(
        queue="gastos",
        on_message_callback=callback,
        auto_ack=False,   # ACK manual para no perder mensajes si algo falla
    )

    print("[INFO] Consumer listo. Esperando mensajes...")
    channel.start_consuming()


if __name__ == "__main__":
    start_consumer()