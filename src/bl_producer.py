import os.path
from builtins import KeyboardInterrupt

import simplejson as json
import boto3
import json
import sys

from pymysqlreplication import BinLogStreamReader
from pymysqlreplication.row_event import (
    DeleteRowsEvent,
    UpdateRowsEvent,
    WriteRowsEvent,
)


def load_config(environment):
    file_path = os.path.join('environments', f'{environment}.json')
    with open(file_path) as json_data_file:
        data = json.load(json_data_file)
    return data


def put_to_kinesis(configurations):
    try:
        kinesis = boto3.client("kinesis", region_name='us-east-1')
        db_config = configurations['database']
        print(f"Database hostname: {db_config['hostname']}")
        kinesis_config = configurations['kinesis']
        stream = db_connection(db_config)
        for bin_log_event in stream:
            for row in bin_log_event.rows:
                print(">>> start event")
                event = {"schema": bin_log_event.schema,
                         "table": bin_log_event.table,
                         "type": type(bin_log_event).__name__,
                         "row": row}
                print(">>> event", event)
                print({kinesis_config['stream_name']})
                response = kinesis.put_record(StreamName=kinesis_config['stream_name'], Data=json.dumps(event, default=str),
                                              PartitionKey="default")
                print(">>>response", response)
    except KeyboardInterrupt:
        print("Its okay")


def db_connection(db_config):
    rds_host = db_config["hostname"]
    rds_port = db_config["port"]
    db_user = db_config["username"]

    rds_client = boto3.client("rds", region_name='us-east-1')
    token = rds_client.generate_db_auth_token(
        DBHostname=rds_host,
        Port=rds_port,
        DBUsername=db_user,
        Region='us-east-1'
    )
    print(token)

    mysql_settings = {
        "host": rds_host,
        "port": rds_port,
        "user": db_user,
        "passwd": token,
        "database": 'SubroPROD',
        "ssl_ca": '/amiity/us-east-1-bundle.pem'
    }

    print(">>> listener start streaming to:mysql_data")
    return BinLogStreamReader(
        connection_settings=mysql_settings,
        server_id=100,
        blocking=True,
        resume_stream=True,
        only_events=[DeleteRowsEvent])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("run command -> python binary_log_producer.py <env>")
        sys.exit(1)

    env = sys.argv[1]
    config = load_config(env)
    put_to_kinesis(config)

