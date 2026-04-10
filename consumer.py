import pika
import json
import time
import os
from pymongo import MongoClient

MONGO_URL = os.getenv("MONGO_URL", "mongodb://admin:password123@mongodb:27017/")
RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "password123")

# mongo: MongoClient = MongoClient("mongodb://admin:password123@mongodb:27017/") --> Asi lo quiere el mypy
mongo = MongoClient(MONGO_URL)   # type: ignore
db = mongo["finanzas"]
coleccion = db["gastos"]

# Eesperar hasta que Rabbit esté listo
while True:
    try:
        credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(
                host=RABBITMQ_HOST,
                credentials=credentials
            )
        )
        break
    except pika.exceptions.AMQPConnectionError:
        print("Esperando a RabbitMQ...")
        time.sleep(5)

channel = connection.channel()
channel.queue_declare(queue="gastos")

def callback(ch, method, properties, body):
    data = json.loads(body)
    print("Insertando en Mongo:", data)
    coleccion.insert_one(data)

channel.basic_consume(
    queue="gastos",
    on_message_callback=callback,
    auto_ack=True
)

print("Esperando mensajes...")
channel.start_consuming()