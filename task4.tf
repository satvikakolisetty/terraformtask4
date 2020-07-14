provider "aws" {
region = "ap-south-1"
profile = "iamuser"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "publicsubnet"
  }
}
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "privatesubnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}

resource "aws_route_table" "forig" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "igroutetable"
  }
}

resource "aws_route_table_association" "asstopublic" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.forig.id
}

resource "aws_security_group" "webserver" {
  name        = "wordpress"
  description = "Allow http and ssh"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_sg"
  }
}

resource "aws_eip" "nat" {
  vpc=true 
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id =  aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "gw NAT"
  }
}
resource "aws_route_table" "forprivate" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }

 

  tags = {
    Name = "fordatabase"
  }
}
resource "aws_route_table_association" "nat" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.forprivate.id
}

resource "aws_security_group" "database" {
  name        = "for_sql"
  description = "Allow sql and ssh"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    security_groups = [aws_security_group.webserver.id]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db_sg"
  }
}

resource "aws_instance" "wordpress" {
  ami             = "ami-000cbce3e1b899ebd"
  instance_type   = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.webserver.id]
  associate_public_ip_address = true
  key_name = "mykey"
 

  
  tags = {
    Name = "wordpress"
  }
}

resource "aws_instance" "mysql" {
  ami             = "ami-0019ac6129392a0f2"
  instance_type   = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.database.id]
  key_name = "mykey"
 

  
  tags = {
    Name = "mysql"
  }
}

