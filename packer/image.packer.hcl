build ami-build


name: 'AWS AMI Build'

on: [workflow_call]


env:
  PRODUCT_VERSION: "1.8.6" # or: "latest"

jobs:
  packer:
    runs-on: ["self-hosted","amit-runner"]
    name: AMI Build
    defaults:
      run:
        working-directory: packer
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
         # role-to-assume: ${{ vars.AWS_PROD_ROLE }}
         # role-session-name: amiity-cdc-golden-ami-build
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_DCE }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY_DCE }}
          aws-region: us-east-1

      - name: Install AWS CLI and SSM Plugin
        run: |
          sudo apt-get update
          sudo apt-get install -y awscli
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
          sudo dpkg -i session-manager-plugin.deb

      - name: Setup `packer`
        uses: hashicorp/setup-packer@main
        id: setup
        with:
          version: ${{ env.PRODUCT_VERSION }}

      - name: Packer Init
        run: packer init ../packer/cdc-image.pkr.hcl
        env:
          PACKER_GITHUB_API_TOKEN: ${{ github.token }}

      - name: Validate Template
        run: packer validate -syntax-only ../packer/cdc-image.pkr.hcl

      - name: Packer Build
        run: packer build -color=false -on-error=cleanup ../packer/cdc-image.pkr.hcl
		
		
		
		
		
		
name: 'AWS EC2 Build'

on:
  workflow_call:
    inputs:
      instanceProfileName:
        required: true
        type: string
      instanceName:
        required: true
        type: string
      environment:
        required: true
        type: string
      awsRegion:
        required: false
        type: string
        default: "us-east-1"

jobs:
  launch_ec2:
    name: Launch ${{ inputs.environment }}
    runs-on: [ "self-hosted","amit-runner" ]
    environment:
      name: ${{ inputs.environment }}
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_DCE }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY_DCE }}
          # role-to-assume: ${{ vars.SUBRO_AWS_PROD_ROLE }}
          # role-session-name: amiity-cdc-ec2-launch
          aws-region: us-east-1

      - name: Install AWS CLI and SSM Plugin
        run: |
          sudo apt-get update
          sudo apt-get install expect -qq > /dev/null;
          sudo apt-get install -y awscli
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
          sudo dpkg -i session-manager-plugin.deb

      - name: Read old Instance Id
        id: old-instance-id
        run: |
          INSTANCE_ID=$(aws ec2 describe-instances --region ${{ inputs.awsRegion }} \
            --filters 'Name=tag:Name,Values=${{ inputs.instanceName }}' 'Name=instance-state-name,Values=running' \
            --query 'Reservations[].Instances[].InstanceId' \
            --output text)
          echo "INSTANCE_ID=$INSTANCE_ID" >> $GITHUB_OUTPUT

      - name: Read AMI Id
        id: read-image-id
        run: |
          LATEST_AMI_ID=$(aws ec2 describe-images \
            --region ${{ inputs.awsRegion }} \
            --owners "8597097790" \
            --filters "Name=tag:AppName,Values=CDC" \
            --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
            --output text)
          echo "LATEST_AMI_ID=$LATEST_AMI_ID" >> $GITHUB_OUTPUT

      - name: Launch EC2
        run: |
          aws ec2 run-instances \
            --image-id ${{ steps.read-image-id.outputs.LATEST_AMI_ID }} \
            --instance-type t2.micro \
            --subnet-id subnet-0b60cc8bd463018 \
            --security-group-ids sg-0f86315fef1b654 \
            --iam-instance-profile Name=${{ inputs.instanceProfileName }} \
            --associate-public-ip-address \
            --count 1 \
            --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value= ${{ inputs.instanceName }}},{Key=Product,Value=amiity},{Key=AppName,Value=CDC},{Key=Environment,Value= ${{ inputs.environment }}}]' \

      - name: Read Instance Id
        id: instance-id
        run: |
          INSTANCE_ID=$(aws ec2 describe-instances --region ${{ inputs.awsRegion }} \
            --filters 'Name=tag:Name,Values=${{ inputs.instanceName }}' \
            --query 'sort_by(Reservations[].Instances[], &LaunchTime)[-1].InstanceId' \
            --output text)
          echo "INSTANCE_ID=$INSTANCE_ID" >> $GITHUB_OUTPUT

      - name: Run script
        run: |
          sleep 180 && aws ssm send-command --region ${{ inputs.awsRegion }} \
          --instance-ids ${{ steps.instance-id.outputs.INSTANCE_ID }} \
          --document-name "AWS-RunShellScript" \
          --parameters commands='["cd /amiity/cdc/src/" ,"python3 binary_log_producer.py ${{ inputs.environment }} > log_producer.out"]'

      - name: Terminate old instance
        if: steps.old-instance-id.outputs.INSTANCE_ID != ''
        run: |
          aws ec2 terminate-instances  --region ${{ inputs.awsRegion }} --instance-ids ${{ steps.old-instance-id.outputs.INSTANCE_ID }}




launch instance.yml



name: 'Build AMI and Launch EC2'

on:
  # schedule:
  #   - cron: '0 4 * * *'
  push:
    branches:
      - US1107247
    workflow_dispatch:
      
jobs:
 # build:
 #   uses: ./.github/workflows/build-ami.yml
 #   secrets: inherit

  qa3:
    uses: ./.github/workflows/instance-template.yml
 #   needs: build
    secrets: inherit
    with:
      instanceProfileName: 'cdc-instance-profile'
      environment: 'qa3'
      instanceName: 'change-data-capture-qa3'

  qa2:
    uses: ./.github/workflows/instance-template.yml
    needs: qa3
    secrets: inherit
    with:
      instanceProfileName: 'cdc-instance-profile'
      environment: 'qa2'
      instanceName: 'change-data-capture-qa2'

  uat:
    uses: ./.github/workflows/instance-template.yml
    needs: qa2
    secrets: inherit
    with:
      instanceProfileName: 'cdc-instance-profile'
      environment: 'uat'
      instanceName: 'change-data-capture-uat'

  prod:
    uses: ./.github/workflows/instance-template.yml
    needs: uat
    secrets: inherit
    with:
      instanceProfileName: 'cdc-instance-profile'
      environment: 'prod'
      instanceName: 'change-data-capture-prod'






pkr


packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  ami_tags = {
    "Product"       = "amiity"
    "AppName"       = "CDC"
  }
  timestamp = formatdate("YYYYMMDDHHmmss", timestamp())
}

build {
  name    = "cdc-packer"
  sources = [
    "source.amazon-ebs.cdc_golden_ami"
  ]

  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install python3 -y",
      "sudo mkdir -p /amiity/cdc/src",
    ]
  }

  provisioner "file" {
    destination = "/tmp"
    source      = "../src"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/src/* /amiity/cdc/src/"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo pip3 install -U pip",
      "sudo pip3 install -r /amiity/cdc/src/requirements.txt"
    ]
  }
}

source "amazon-ebs" "cdc_golden_ami" {
  ami_name      = "change-data-capture-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "us-east-1"

  source_ami_filter {
    filters = {
      name                = "amiity/Amazon_Linux_2_*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = [
      "626017279283"
    ]
  }

  temporary_iam_instance_profile_policy_document {
    Version = "2012-10-17"
    Statement {
      Effect = "Allow"
      Action = [
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation"
      ]
      Resource = ["*"]
    }
    Statement {
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = ["*"]
    }
    Statement {
      Effect = "Allow"
      Action = [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ]
      Resource = ["*"]
    }
  }

  associate_public_ip_address = true
  communicator                = "ssh"
  ssh_username                = "ec2-user"
  ssh_interface               = "session_manager"

  subnet_filter {
    filters = {
      "tag:Name" : "amiity-QA3-Private-*"
    }
    most_free = true
    random    = true
  }

  tags = local.ami_tags

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}



.json


{
  "database": {
    "hostname": "",
    "port": 3306,
    "username": "cdcuser"
  },
  "kinesis": {
    "stream_name": "amiity-cdc-prod-stream"
  }
}



code



import os.path
from builtins import KeyboardInterrupt

import simplejson as json
import boto3
import json
import sys

from boto.gs.key import Key
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
        print()


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




requiment



awscli==1.22.30
beautifulsoup4==4.10.0
boto==2.49.0
boto3==1.20.30
botocore==1.23.30
mysql-replication==0.43.0
PyMySQL==1.1.0
python-dateutil==2.8.2
PyYAML==5.4.1
s3transfer==0.5.0
simplejson==3.2.0
virtualenv==20.13.0



secret test


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




gitignore


# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
.idea/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
#   For a library or package, you might want to ignore these files since the code is
#   intended to run in multiple environments; otherwise, check them in:
# .python-version

# pipenv
#   According to pypa/pipenv#598, it is recommended to include Pipfile.lock in version control.
#   However, in case of collaboration, if having platform-specific dependencies or dependencies
#   having no cross-platform support, pipenv may install dependencies that don't work, or not
#   install all needed dependencies.
#Pipfile.lock

# poetry
#   Similar to Pipfile.lock, it is generally recommended to include poetry.lock in version control.
#   This is especially recommended for binary packages to ensure reproducibility, and is more
#   commonly ignored for libraries.
#   https://python-poetry.org/docs/basic-usage/#commit-your-poetrylock-file-to-version-control
#poetry.lock

# pdm
#   Similar to Pipfile.lock, it is generally recommended to include pdm.lock in version control.
#pdm.lock
#   pdm stores project-wide configurations in .pdm.toml, but it is recommended to not include it
#   in version control.
#   https://pdm.fming.dev/#use-with-ide
.pdm.toml

# PEP 582; used by e.g. github.com/David-OConnor/pyflow and github.com/pdm-project/pdm
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyCharm
#  JetBrains specific template is maintained in a separate JetBrains.gitignore that can
#  be found at https://github.com/github/gitignore/blob/main/Global/JetBrains.gitignore
#  and can be added to the global gitignore or merged into this file.  For a more nuclear
#  option (not recommended) you can uncomment the following to ignore the entire idea folder.
#.idea/

