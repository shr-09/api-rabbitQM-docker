FROM python:3.9-slim

WORKDIR /app

COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto del codigo
COPY api/ ./api
COPY worker/ ./worker

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]