import pika
import json
import time
from pymongo import MongoClient

mongo = MongoClient("mongodb://admin:password123@mongodb:27017/")
db = mongo["finanzas"]
coleccion = db["gastos"]

# Eesperar hasta que Rabbit esté listo
while True:
    try:
        credentials = pika.PlainCredentials("admin", "password123")
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(
                host="rabbitmq",
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
