import json

import boto3
from botocore.exceptions import ClientError


def get_secret():
    dynamic_part = 'qa3'

    secret_name = f'/amiity/payerfilestatus_{dynamic_part}'
    region_name = "us-east-1"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    secret = json.loads(get_secret_value_response['SecretString'])
    key_value = secret['spring.datasource.username']
    print("secret value :", key_value)


get_secret()
