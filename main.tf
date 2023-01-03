resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = local.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-public${count.index}"
  }
}

resource "aws_subnet" "private" {
  count                   = local.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, "${local.subnet_count + count.index}")
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-private${count.index}"
  }
}

resource "aws_eip" "eip" {
  vpc = true
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}"
  }
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-private"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = local.subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "bastion-sg" {
  name_prefix = "${local.common_tags.environment}-${local.common_tags.project}-bastion-"
  description = "Allow 22 from anywhere"
  vpc_id      = aws_vpc.vpc.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-bastion"
  }
}

resource "aws_security_group" "backend-sg" {
  name_prefix = "${local.common_tags.environment}-${local.common_tags.project}-backend-"
  description = "Allow 22 from bastion server and 3306 access from frontend"
  vpc_id      = aws_vpc.vpc.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-backend"
  }
}

resource "aws_security_group" "frontend-sg" {
  name_prefix = "${local.common_tags.environment}-${local.common_tags.project}-frontend-"
  description = "Allow 222 from bastion server and 80 & 443 from public"
  vpc_id      = aws_vpc.vpc.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.common_tags.environment}-${local.common_tags.project}-frontend"
  }
}

resource "aws_security_group_rule" "bastion-ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.bastion-sg.id
}
resource "aws_security_group_rule" "frontend-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.frontend-sg.id
}
resource "aws_security_group_rule" "frontend-https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.frontend-sg.id
}
resource "aws_security_group_rule" "frontend-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion-sg.id
  security_group_id        = aws_security_group.frontend-sg.id
}

resource "aws_security_group_rule" "backend-mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.frontend-sg.id
  security_group_id        = aws_security_group.backend-sg.id
}

resource "aws_security_group_rule" "backend-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion-sg.id
  security_group_id        = aws_security_group.backend-sg.id
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.project}-${var.environment}"
  public_key = file("mykey.pub")

  tags = {
    Name = "${var.project}-${var.environment}"
  }
}

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
  depends_on = [aws_nat_gateway.nat-gw]
}

resource "aws_route53_zone" "private" {
  name = var.private_domain
  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}

resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.private_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.backend.private_ip]
}

resource "aws_route53_record" "wordpress" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "wordpress.${var.public_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.frontend.public_ip]
}
