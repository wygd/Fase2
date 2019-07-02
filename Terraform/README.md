# Terraform y AWS
Terraform es un software de infraestructura como código (infrastructure as code) desarrollado por HashiCorp. Permite a los usuarios definir y configurar la infraestructura de un centro de datos en un lenguaje de alto nivel, generando un plan de ejecución para desplegar la infraestructura en una gran variedad de proveedores de IaaS, como lo son AWS, Google Cloud, DigitalOcean, etc.

# Instalación de Terraform v0.12.3 en Ubuntu 14.04 LTS
 
 Terraform se encuentra en el sitio oficial https://www.terraform.io/downloads.html, tenemos a disposición una lista de links de donde podemos elegir el instalador que se adecue a nuestro sistema operativo, en este caso, copiamos la url de la version de Terraform para Linux 64-bits, que se encuentra en el siguiente link:
 https://releases.hashicorp.com/terraform/0.12.3/terraform_0.12.3_linux_amd64.zip
 
 Al tener descargado el archivo binario, lo desempaquetamos en algun directorio de donde sabemos que no lo borraremos en un futuro.
 Al tener el archivo desempaquetado, debido a que @Terraform se encuentra en la forma de un archivo binario, simplemente tenemos que indicarle al sistema su ubicacioón, para poder tener acceso a Terraform desde cualquier ubicación en nuestra pc.
 Esto lo hacemos modificando el archivo ~/.profile, agregamos al final del archivo la linea de la forma:
 
 export PATH="$PATH:/path/de/terraform"
 
 Guardamos el archivo, pero aun hay un paso que realizar, en este momento el sistema aun no reconoce la variable de entorno que acabamos de agregar, lo hara hasta despues de un reinicio del sistema, pero para evitar reiniciar el sistema y poder hacer uso de Terraform de manera inmediata, ejecutamos el siguiente comando:
 source ~/.profile
 Este comando forzara la actualización de las variables de entorno, y con esto, ya tenemos a disposición terraform, para poder comenzar a trabajar.
 
 # Uso de Terraform
 
 Terraform posee una gran cantidad de modulos y herramientas necesarias para poder trabajar con los distintos proveedores de infraestructura en la nube. En este caso veremos el funcionamiento para AWS.
 
 Actualmente deseamos crear una instancia de EC2, la cual contara con un servidor nginx instalado y es accesible desde la web. Para poder lograr nuestro objetivo necesitamos la siguiente infraestructura de AWS:
 1) VPC.
 2) Subnet publica en la VPC.
 3) Security group, que permita la conexión por medio de SSH y peticiones HTTP en el puerto 80.
 4) Instancia EC2 con servidor NGINX instalado.
 
 # Creación del archivo main.tf
 Terraform tiene hace uso de archivos .tf, en los cuales busca los elementos de nuestra infraestructura.
 Para iniciar un proyecto de terraform,nos dirigimos a la carpeta donde deseamos crear nuestro proyecto de terraform y ejecutamos desde consolo el siguiente comando:
 terraform init
 Este comando creara en el directorio donde es ejecutado una carpeta llamada .terraform, donde almacenara lo que necesita para poder crear en un futuro la infraestructura.
 Necesitamos indicarle a Terraform con que proveedor de IaaS deseamos trabajar, hacemos uso del elemento llamado "provider", el cual es un pequeño submodulo el cual es descargado y almacenado en la carpeta .terraform. Este submodulo es un controlador, el cual utiliza la API de los proveedores de IaaS para poder interactuar con sus plataformas de manera remota.

Debido a que utilizaremos AWS, la forma de agregar el provider de AWS es la siguiente:
```
  provider "aws" {
    access_key = "${var.aws_access_key}" //este tipo de datos sensibles se almacenan en un archivo privado, para evitar hacerlos publicos.
    secret_key = "${var.aws_secret_key}"
  region     = "us-east-1" //aqui indicamos la region en la que deseamos trabajar
}
```
Ahora que ya hemos indicado a terraform que deseamos trabajar con AWS, y ademas le hemos proporcionado de las claves necesarias para poder realizar una conexión con la plataforma, podemos comenzar a definir la infraestructura que deseamos que terraform cree en AWS. A cada uno de los elementos que formaran nuestra infraestructura se les conoce como "resource", estos "resource" se pueden referir a elementos como VPC, Subnets, Grupos de seguridad, instancias EC2, buckets S3, etc. 

Lo primero que crearemos sera la VPC donde agregaremos luego una subnet publica y finalmente nuestra instancia de EC2.

## Configuración de Red

### Creacion de VPC:
```
//primero escribimos la palabra reservada resource, para indicarle a terraform que lo que estamos 
definiendo es un resource, es decir un elemento de infraestructura. El primer argumento le indica que servicio de AWS
se utilizara, en este caso es "aws_vpc", es decir, una VPC de AWS, lo siguiente es el nombre con el que nos referiremos 
al resource a lo largo del archivo.
resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_vpc}" #aqui se indica el cidr para la VPC
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}
```
### Creación de una Internet gateway
```
#De esta forma podemos proveer de acceso a internet a nuestra VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}
```
### Creación de Subnet Publica
```
resource "aws_subnet" "subnet_public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr_subnet}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.availability_zone}"
  tags = {
    "Environment" = "${var.environment_tag}"
  }
}
```
### Creación de Tabla de Ruteo para la VPC
```
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
```

### Asociación de la tabla de ruteo creada con la Subnet publica
```
resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = "${aws_subnet.subnet_public.id}"
  route_table_id = "${aws_route_table.rtb_public.id}"
}
```

### Creacin de grupo de seguridad, habilitando conexión SSH y HTTP
```
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
```
### Creacin de instancia EC2
```
resource "aws_instance" "fase2" {
  ami             = "ami-024a64a6685d05041" # ami de ubuntu server 18.04lts 64-bit x86
  instance_type   = "t2.micro" # se selecciona el tipo de instancia.
  subnet_id = "${aws_subnet.subnet_public.id}" #se asocia la subnet creada anteriormente
  vpc_security_group_ids = ["${aws_security_group.sg_fase2.id}"] #se agrega el segurity group con conexion ssh y http
  key_name = "NombreLlave" # aqui se indica el nombre del archivo de llaves que utilizaremos para conectarnos con la instancia.
  
  
  #un provisioner permite tener interaccion con nuestra instancia, como por ejemplo un provisioner de tipo "file", permite
  #tomar un archivo en la maquina donde se esta ejecutando terraform,y copiarlo a nuestra instancia.
  provisioner "file" {
    source="pagina.html" #path del archivo fuente
    destination="~/index.html" #path del destino donde se copiara el archivo
    #para poder realizar la conexion, es necesario declarar un objeto de tipo connection, el cual se encarga de realizar
    #una conexion ssh por defecto, haciendo uso de los parametros como user, private_key y el host
    connection { 
      user="${var.INSTANCE_USERNAME}"
      private_key="${file("${var.PATH_TO_PRIVATE_KEY}")}"
      host = "${aws_instance.fase2.public_dns}"
      timeout  = "5m"#tiempo maximo de espera
    }
  }
#este tipo de provisiones permite ejecutar comandos en consola de manera remota, de igual manera debemos de proveerle un objeto de conexion.
  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin:/bin/sbin",
      "sudo echo 'Waiting for the network'",
      "sudo sleep 30",
      "sudo apt update",
      "sudo apt -y install nginx", #se instala nginx
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
    value = "${aws_instance.fase2.public_dns}"# aqui se devuelve el dns publico de la instancia que se creo, por medio del 
    #cual podemos acceder a nuestra instancia desde el navegador. 
}
```
