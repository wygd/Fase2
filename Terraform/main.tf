provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}


#resources
resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_vpc}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr_subnet}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.availability_zone}"
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = "${aws_subnet.subnet_public.id}"
  route_table_id = "${aws_route_table.rtb_public.id}"
}

resource "aws_security_group" "sg_fase2" {
  name = "sg_fase2"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from the VPC
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port=80
      to_port =80
      protocol="tcp"
      cidr_blocks=["0.0.0.0/0"]
  }
  
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Environment" = "${var.environment_tag}"
  }
}






resource "aws_instance" "fase2" {
  ami             = "ami-024a64a6685d05041" #ubuntu server 18.04lts 64-bit x86
  instance_type   = "t2.micro"
  subnet_id = "${aws_subnet.subnet_public.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_fase2.id}"]
  key_name = "KeySeminario1"
  
  provisioner "file" {
    source="pagina.html"
    destination="~/index.html"
    connection {
      user="${var.INSTANCE_USERNAME}"
      private_key="${file("${var.PATH_TO_PRIVATE_KEY}")}"
      host = "${aws_instance.fase2.public_dns}"
      timeout  = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin:/bin/sbin",
      "sudo echo 'Waiting for the network'",
      "sudo sleep 30",
      "sudo apt update",
      "sudo apt -y install nginx",
      "sudo chmod 777 -R /var/www",
      "cat ~/index.html >> /var/www/html/index.nginx-debian.html",
      "sudo service nginx start",
    ]
    connection {
      user="${var.INSTANCE_USERNAME}"
      private_key="${file("${var.PATH_TO_PRIVATE_KEY}")}"
      host = "${aws_instance.fase2.public_dns}"
      timeout  = "5m"
    }
  }
  tags = {
    Name = "fase2-terraform"
  }

}



output "aws_instance_public_dns" {
    value = "${aws_instance.fase2.public_dns}"
}
