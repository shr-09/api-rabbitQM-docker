FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias basicas
RUN pip install --no-cache-dir fastapi pydantic pymongo uvicorn pika

# Copiar el resto del codigo
COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
