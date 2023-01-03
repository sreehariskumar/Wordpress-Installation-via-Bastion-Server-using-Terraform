# Wordpress-Installation-via-Bastion-Server-using-Terraform

### A terraform project to automate the creation of a VPC and custom subnets and to launch instances using Terraform to host a wordpress website.




[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

#### The code is built using the following versions:
| Provider | Terraform |
| ------ | ------ |
| terraform-provider-aws_v4.48.0_x5 | Terraform v1.3.6 |

## Requirements
- An IAM user with programmatic access with AmazonEC2FullAccess & AmazonRoute53FullAccess permissions.
- Create a SSH key pair in your local system.
- Create a separate project directory to keep all the necessary files.

## Features

Create a terraform code to:
- Create a VPC with 2 public subnets and 1 private subnet
- Create an Internet Gateway & NAT Gateway
- Import a locally created SSH key to AWS login to the server
- Create security groups with custom rules
- Launch bastion server and frontend server in the public subnet and a backend server in private subnet
- Create private hosted zone and a record pointing to the private ip of the backend instance
- Create a record in a public hosted zone pointing to the public ip of the frontend instance to access the wordpress website

## Project Description
This project is developed to demonstrate how to automate the installation of WordPress application in AWS using Terraform. The frontend of the website is hosted on an independant EC2 instance and the backend is managed using a second EC2 instance. Access to the backend will be restricted as this is created within a private subnet. Public SSH access into both these instances are only be possible though a third EC2 instance called a Bastion server. Frontend server is capable of accepting HTTP & HTTPS connections.

## AWS resources and their purpose in this project

**AWS VPC** -This project is entirely created on an independent VPC.

**AWS InternetGateway** - The Internet gateway provides internet connectivity into this VPC.

**AWS Subnet** - The project is configured to create private & public subnets using the cidrsubnet() function of terraform based on the number of Availability Zones in the working Region.

**AWS Nat-Gateway** - NAT gateway enables internet connectivity for instances created under private subnet.

**AWS Route Table** - For this project, we need route tables for private as well as public subnets each.

**AWS Elastic IP** - An elastic IP address should be assigned to NAT Gateway.

**Security Groups** - All three instances comes with indipendent security group and related group rules as follows: 
1. **Bastion-server Security Group** : This security group allows inbound SSH traffic from public internet to bastion instance.
2. **Frontend-server Security Group** : The frontend-server security groups allows SSH traffic only from Bastion server and HTTP & HTTPS traffic from internet.
3. **Backend-server Security Group** - This security groups allows inbound SSH connection only from Bastion server security group and MySQL connection from Frontend-server security group.

**AWS Keypair** - All SSH access are key-based. A ssh key-pair is generated locally and the public key is uploaded into the AWS using terraform.

**AWS Route53** - This project use both Public & Private Hosted Zone to create DNS records for Backend server and Frontend server

**Private Hosted Zone** - Since updating the value of DB_HOST in wp-config.php file is challenging, a private hosted zone is created to define an A record whose pointing to the private IP address of the Backend-server. This private domain is used to connect to the backend instance.

**Public Hosted Zone** - An A record pointing to frontend-server public IP is created within the existing Public hosted zone to access the WordPress site.

**AWS EC2 Instance** - Three EC2 instances of type t2.micro are used for this project. Services like Apache and PHP7.4 are installed on the Frontend-server whereas, MariaDB package for managing the database of the application is deployed on the Backend-server  which is placed in a private network. A third EC2 instance, Bastion-server allows the administrators to gain SSH access to both frontend and backend servers.

Use the following command to clone the repository
```s
git clone https://github.com/sreehariskumar/Wordpress-Installation-via-Bastion-Server-using-Terraform
```
Run the following commands
```s
cd Wordpress-Installation-via-Bastion-Server-using-Terraform
terraform init
terraform validate
terraform plan
terraform apply
```
