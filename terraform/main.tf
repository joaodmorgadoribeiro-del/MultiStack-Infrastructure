
#Data sources

data "aws_availability_zones" "available" {
  state = "available"
}

 # VPC
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  data_azs             = data.aws_availability_zones.available.names
}



data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Groups

# Instance A – Frontend (Vote :5000, Result :4000, SSH)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "Allow HTTP traffic to Vote and Result services plus SSH"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Vote app (Flask)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Result app (Node.js)"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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
    Name    = "${var.project_name}-sg-frontend"
    Project = var.project_name
    Tier    = "frontend"
  }
}

# # Instance B – Backend (Redis :6379, Worker – internal only)
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Allow Redis from frontend and SSH from VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Redis from frontend"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-backend"
    Project = var.project_name
    Tier    = "backend"
  }
}

# # Instance C – Database (PostgreSQL :5432 from backend and frontend)
resource "aws_security_group" "database" {
  name        = "${var.project_name}-sg-database"
  description = "Allow PostgreSQL from backend and frontend tiers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description     = "PostgreSQL from frontend (Result reads DB)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-database"
    Project = var.project_name
    Tier    = "database"
  }
}

# --- INSTANCE A: Launch Template for ASG (Frontend) ---
resource "aws_launch_template" "frontend" {
  name_prefix = "${var.project_name}-frontend-lt-"

  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name = "joao-irene-useast1"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.frontend.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-instance-a-frontend"
      Project = var.project_name
      Tier    = "frontend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


#Creating state
resource "aws_s3_bucket" "tf_state" {
  bucket = "terraform-state-project1-joao-irene"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

module "frontend" {
  source         = "./modules/instance"
  has_public_ip  = true
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.frontend.id
  subnet         = module.vpc.public_subnet_ids[0]
  key_name       = "joao-irene-useast1"
  tags           = { Name = "frontend-joao-irene" }
}

module "backend" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.backend.id
  subnet         = module.vpc.private_subnet_ids[0]
  key_name       = "joao-irene-useast1"
  tags           = { Name = "backend-joao-irene" }
}

module "database" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.database.id
  subnet         = module.vpc.private_subnet_ids[1]
  key_name       = "joao-irene-useast1"
  tags           = { Name = "database-joao-irene" }
}