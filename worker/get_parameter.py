import boto3
import os
from botocore.exceptions import ClientError
from typing import Optional

def get_ssm_parameter(name: str, default: Optional[str] = None) -> Optional[str]:
    """
    Consulta un parámetro del Parameter Store de AWS.
    Si no existe, retorna el valor `default`.
    """
    region = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    client = boto3.client("ssm", region_name=region)
    try:
        response = client.get_parameter(Name=name)
        return str(response["Parameter"]["Value"])
    except ClientError as e:
        if e.response["Error"]["Code"] == "ParameterNotFound":
            print(f"[WARN] Parámetro '{name}' no encontrado. Usando valor por defecto: '{default}'")
            return default
        raise  # Re-lanza errores inesperados (permisos, red, etc.)


if __name__ == "__main__":
    rabbitmq_ip = get_ssm_parameter(
        name=os.getenv("SSM_RABBITMQ_PARAM", "/message-queue/dev/rabbitmq/public_ip"),
        default="localhost"
    )
    print(f"RabbitMQ IP: {rabbitmq_ip}")