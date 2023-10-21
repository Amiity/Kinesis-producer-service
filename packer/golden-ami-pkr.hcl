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
