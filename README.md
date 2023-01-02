# Wordpress-Installation-via-Bastion-Server-using-Terraform

### A terraform project to automate the creation of a VPC and custom subnets and to launch instances using Terraform to host a wordpress website.




[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

#### The code is build using the following versions:
| Provider | Terraform |
| ------ | ------ |
| terraform-provider-aws_v4.48.0_x5 | Terraform v1.3.6 |

## Requirements
- An IAM user with programmatic access and EC2FullAccess, Route53FullAccess permissions.
- Create a separate project directory to keep all the necessary files.
- Create a ssh key pair in your local system.

### Userdata scripts: 
| Scripts | Link |
| ------ | ------ |
| bastion.sh | https://pastebin.com/UmcsJTbi |
| frontend.sh | https://pastebin.com/BxBq9JXy |
| backend.sh | https://pastebin.com/UCYr0tVm |

## Features

Create a terraform code to:
- Create a VPC with 2 public subnets and 1 private subnet
- Create an Internet Gateway & NAT Gateway
- Import a locally created SSH key to AWS login to the server
- Create security groups with custom rules
- Launch bastion server and frontend server in the public subnet and a backend server in private subnet
- Create private hosted zone and a record pointing to the private ip of the backend instance
- Create a record in a public hosted zone pointing to the public ip of the frontend instance to access the wordpress website

### Let's get started.

1. Create a variables.tf with the following contents file to store the variables.
```sh
variable "project" {
  default     = "zomato"
  description = "project name"
}

variable "environment" {
  default     = "production"
  description = "project env"
}

variable "region" {
  default     = "ap-south-1"
  description = "project region"
}

variable "access_key" {
  default = "XXXXXXXXXXXX"
  description = project access key
}

variable "secret_key" {
  default = "XXXXXXXXXXXX"
  description = project secret key
}

variable "instance_ami" {
  default = "ami-0cca134ec43cf708f"
}

variable "instance_type" {
  default = "t2.micro"
}

locals {
  subnets = length(data.aws_availability_zones.available.names)
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
  description = cidr block to create vpc
}

locals {
  common_tags = {
    project     = var.project
    environment = var.project
  }
}

variable "private_domain" {
  default = "sreehari.local"
  description = "domain in private hosted zone"
}

variable "public_domain" {
  default = "1by2.online"
  description = "record to access wordpress website"
}
```
2. Create a datasource.tf with the following contents file to fetch datasources.
```s
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "mydomain" {
  name         = var.public_domain
  private_zone = false
}
```

3. Create a provider.tf file  with the following contents required for terraform initialization.

```s
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
  default_tags {
    tags = local.common_tags
  }
}
```
To initialize terraform, run the following command
```s
terraform init
```

4. Now create the main.tf file qith the following configuration to build the infrastructure.
#### Create a cidr block for the VPC

```s
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
```
#### Create an internet gateway to allow traffic flow in the VPC.

```s
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
```
#### Create a public subnet

```s
resource "aws_subnet" "public" {
  count                   = local.subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public${count.index + 1}"
  }
}
```
#### Create a private subnet

```s
resource "aws_subnet" "private" {
  count                   = local.subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, (count.index + local.subnets))
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-private${count.index + 1}"
  }
}
```
#### Create an elastic ip

```s
resource "aws_eip" "nat_ip" {
  vpc = true
}
```
#### Attach the elactic ip to the nat gateway.

```s
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public[2].id

  tags = {
    Name = "${var.project}-${var.environment}"
  }
   depends_on = [aws_internet_gateway.igw]
}
```
#### Create a public route table to route traffic via internet gateway.

```s
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-public"
  }
}
```
#### Create a private route table to route traffic via nat gateway.

```s
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-private"
  }
}
```
#### Associate the public subnets to the public route table

```s
resource "aws_route_table_association" "public" {
  count          = local.subnets
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

#### Associate the private subnets to the private route table


```s
resource "aws_route_table_association" "private" {
  count          = local.subnets
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

#### Create a bastion security group to allow ssh traffic from anywhere

```s
resource "aws_security_group" "bastion-sg" {
  name_prefix = "${var.project}-${var.environment}-"
  description = "Allow ssh from anywhere"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-bastion-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

#### Create a frontend security group to allow ssh traffic from bastion security group and http, https traffic from anywhere

```s
resource "aws_security_group" "frontend-sg" {
  name_prefix = "${var.project}-${var.environment}-"
  description = "Allow http from anywhere and ssh from bastion-sg"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-frontend-sg"

  }
  lifecycle {
    create_before_destroy = true
  }
}
```

#### Create a backend security group to allow ssh traffic from bastion security group and mysql traffic from frontend security group

```s
resource "aws_security_group" "backend-sg" {
  name_prefix = "${var.project}-${var.environment}-"
  description = "Allow sql from frontend-sg and ssh from bastion-sg"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend-sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-backend-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

#### Import the locally create ssh key to AWS

```s
resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.project}-${var.environment}"
  public_key = file("mykey.pub")

  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
```
#### Create the bastion instance in a public subnet with bastion security group and to run a custom userdata script at boot.

```s
resource "aws_instance" "bastion" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.1.id
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  user_data                   = file("bastion.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project}-${var.environment}-bastion"
  }
}
```
#### Create the frontend instance in a public subnet with frontend security group and to run a custom userdata script at boot.

```s
resource "aws_instance" "frontend" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.0.id
  vpc_security_group_ids      = [aws_security_group.frontend-sg.id]
  user_data                   = file("frontend.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project}-${var.environment}-frontend"
  }
}
```
#### Create the backend instance in a privte subnet with backend security group and to run a custom userdata script at boot. This instance will begin creation only after the creation of nat gateway as the instance require traffic flow to install necessary packages

```s
resource "aws_instance" "backend" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.private.0.id
  vpc_security_group_ids      = [aws_security_group.backend-sg.id]
  user_data                   = file("backend.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project}-${var.environment}-backend"
  }
  depends_on = [aws_nat_gateway.nat_gw]
}
```
#### Create a private hosted zone and attach it to the custom VPC

```s
resource "aws_route53_zone" "private" {
  name = var.private_domain
  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}
```
#### Create a record in the private hosted zone pointing to the private ip of the backend server

```s
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.private_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.backend.private_ip]
}
```
#### Create a record in the public hosted zone pointing to the public ip of the frontend instance to access the wordpress website.

```s
resource "aws_route53_record" "wordpress" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "wordpress.${var.public_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.frontend.public_ip]
}
```


Run the following command to validate the code
```s
terraform validate
```
To make a trial run of the code run the following command:
```s
terraform plan
```
To build the infrastructure, run
> The code will make a trial run before applying the changes and asks for the confirmation
> The responce should be "yes", if you're willing to go forward with the build.
```s
terraform apply
```
