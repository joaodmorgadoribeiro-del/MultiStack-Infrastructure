# Data Source
# ─────────────────────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
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

# ─────────────────────────────────────────────────────────────────────────────
# LOCALS
# ─────────────────────────────────────────────────────────────────────────────

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC MODULE
# 2 public subnets (different AZs) for ALB + Bastion
# 2 private subnets for all app instances
# ─────────────────────────────────────────────────────────────────────────────

module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs   # ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = var.private_subnet_cidrs  # ["10.20.11.0/24", "10.20.12.0/24"]
  data_azs             = local.azs
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUPS
# ─────────────────────────────────────────────────────────────────────────────

# ALB SG - accepts HTTP from internet on port 80
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-sg-alb" })
}

# Bastion SG - SSH only from internet
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Allow SSH from internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from internet"
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

  tags = merge(local.tags, { Name = "${var.project_name}-sg-bastion" })
}

# Vote SG - accepts traffic from ALB + SSH from Bastion
resource "aws_security_group" "vote" {
  name        = "${var.project_name}-sg-vote"
  description = "Allow traffic from ALB and SSH from Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Vote app from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-sg-vote", Tier = "frontend" })
}

# Result SG - accepts traffic from ALB + SSH from Bastion
resource "aws_security_group" "result" {
  name        = "${var.project_name}-sg-result"
  description = "Allow traffic from ALB and SSH from Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Result app from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-sg-result", Tier = "frontend" })
}

# Backend SG - Redis from Vote + SSH from Bastion
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Allow Redis from vote/result and SSH from Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Redis from Vote"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.vote.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-sg-backend", Tier = "backend" })
}

# Database SG - PostgreSQL from Backend + Result + SSH from Bastion
resource "aws_security_group" "database" {
  name        = "${var.project_name}-sg-database"
  description = "Allow PostgreSQL from backend and result tiers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from Backend (Worker)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description     = "PostgreSQL from Result"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.result.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-sg-database", Tier = "database" })
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 INSTANCES (via module)
# ─────────────────────────────────────────────────────────────────────────────

# Bastion Host - public subnet, SSH gateway to private instances
module "bastion" {
  source         = "./modules/instance"
  has_public_ip  = true
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.bastion.id
  subnet         = module.vpc.public_subnet_ids[0]
  key_name       = var.key_name
  tags           = merge(local.tags, { Name = "${var.project_name}-bastion", Tier = "bastion" })
}

# Vote instance - private subnet
module "vote" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.vote.id
  subnet         = module.vpc.private_subnet_ids[0]
  key_name       = var.key_name
  tags           = merge(local.tags, { Name = "${var.project_name}-vote", Tier = "frontend" })
}

# Result instance - private subnet
module "result" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.result.id
  subnet         = module.vpc.private_subnet_ids[0]
  key_name       = var.key_name
  tags           = merge(local.tags, { Name = "${var.project_name}-result", Tier = "frontend" })
}

# Backend instance - Redis + Worker - private subnet
module "backend" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.backend.id
  subnet         = module.vpc.private_subnet_ids[0]
  key_name       = var.key_name
  tags           = merge(local.tags, { Name = "${var.project_name}-backend", Tier = "backend" })
}

# Database instance - PostgreSQL - private subnet
module "database" {
  source         = "./modules/instance"
  has_public_ip  = false
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  security_group = aws_security_group.database.id
  subnet         = module.vpc.private_subnet_ids[1]
  key_name       = var.key_name
  tags           = merge(local.tags, { Name = "${var.project_name}-database", Tier = "database" })
}

# ─────────────────────────────────────────────────────────────────────────────
# ALB - Gateway + Reverse Proxy + Load Balancer
# Path-based routing: /vote → vote, /result → result
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids  # 2 public subnets, 2 AZs

  tags = merge(local.tags, { Name = "${var.project_name}-alb" })
}

# Target Group: Vote (:5000)
resource "aws_lb_target_group" "vote" {
  name     = "${var.project_name}-vote-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, { Name = "${var.project_name}-vote-tg" })
}

# Target Group: Result (:4000)
resource "aws_lb_target_group" "result" {
  name     = "${var.project_name}-result-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, { Name = "${var.project_name}-result-tg" })
}

# Listener on port 80 with path-based routing
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action - redirect to vote
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }
}

# Listener Rule: /vote → vote target group
resource "aws_lb_listener_rule" "vote" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }

  condition {
    path_pattern {
      values = ["/vote", "/vote/*"]
    }
  }
}

# Listener Rule: /result → result target group
resource "aws_lb_listener_rule" "result" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }

  condition {
    path_pattern {
      values = ["/result", "/result/*"]
    }
  }
}

# Attach vote instance to vote target group
resource "aws_lb_target_group_attachment" "vote" {
  target_group_arn = aws_lb_target_group.vote.arn
  target_id        = module.vote.instance_id
  port             = 5000
}

# Attach result instance to result target group
resource "aws_lb_target_group_attachment" "result" {
  target_group_arn = aws_lb_target_group.result.arn
  target_id        = module.result.instance_id
  port             = 4000
}

# ─────────────────────────────────────────────────────────────────────────────
# REMOTE STATE (S3 + DynamoDB)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tf_state" {
  bucket = "terraform-state-project1-joao-irene"
  tags   = merge(local.tags, { Name = "terraform-state-project1-joao-irene" })
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

  tags = merge(local.tags, { Name = "terraform-lock" })
}


# #Data sources

# data "aws_availability_zones" "available" {
#   state = "available"
# }

#  # VPC
# module "vpc" {
#   source               = "./modules/vpc"
#   project_name         = var.project_name
#   vpc_cidr             = var.vpc_cidr
#   public_subnet_cidrs  = var.public_subnet_cidrs
#   private_subnet_cidrs = var.private_subnet_cidrs
#   data_azs             = data.aws_availability_zones.available.names
# }



# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"]
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# # Security Groups

# # Instance A – Frontend (Vote :5000, Result :4000, SSH)
# resource "aws_security_group" "frontend" {
#   name        = "${var.project_name}-sg-frontend"
#   description = "Allow HTTP traffic to Vote and Result services plus SSH"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description = "Vote app (Flask)"
#     from_port   = 5000
#     to_port     = 5000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "Result app (Node.js)"
#     from_port   = 4000
#     to_port     = 4000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name    = "${var.project_name}-sg-frontend"
#     Project = var.project_name
#     Tier    = "frontend"
#   }
# }

# # # Instance B – Backend (Redis :6379, Worker – internal only)
# resource "aws_security_group" "backend" {
#   name        = "${var.project_name}-sg-backend"
#   description = "Allow Redis from frontend and SSH from VPC"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description     = "Redis from frontend"
#     from_port       = 6379
#     to_port         = 6379
#     protocol        = "tcp"
#     security_groups = [aws_security_group.frontend.id]
#   }

#   ingress {
#     description = "SSH from VPC"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name    = "${var.project_name}-sg-backend"
#     Project = var.project_name
#     Tier    = "backend"
#   }
# }

# # # Instance C – Database (PostgreSQL :5432 from backend and frontend)
# resource "aws_security_group" "database" {
#   name        = "${var.project_name}-sg-database"
#   description = "Allow PostgreSQL from backend and frontend tiers"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description     = "PostgreSQL from backend"
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     security_groups = [aws_security_group.backend.id]
#   }

#   ingress {
#     description     = "PostgreSQL from frontend (Result reads DB)"
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     security_groups = [aws_security_group.frontend.id]
#   }

#   ingress {
#     description = "SSH from VPC"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name    = "${var.project_name}-sg-database"
#     Project = var.project_name
#     Tier    = "database"
#   }
# }

# # --- INSTANCE A: Launch Template for ASG (Frontend) ---
# resource "aws_launch_template" "frontend" {
#   name_prefix = "${var.project_name}-frontend-lt-"

#   image_id      = data.aws_ami.ubuntu.id
#   instance_type = var.instance_type

#   key_name = "joao-irene-useast1"

#   network_interfaces {
#     associate_public_ip_address = true
#     security_groups             = [aws_security_group.frontend.id]
#   }

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name    = "${var.project_name}-instance-a-frontend"
#       Project = var.project_name
#       Tier    = "frontend"
#     }
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# #Creating state
# resource "aws_s3_bucket" "tf_state" {
#   bucket = "terraform-state-project1-joao-irene"
# }

# resource "aws_s3_bucket_versioning" "versioning" {
#   bucket = aws_s3_bucket.tf_state.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_dynamodb_table" "tf_lock" {
#   name         = "terraform-lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }

# module "frontend" {
#   source         = "./modules/instance"
#   has_public_ip  = true
#   ami            = data.aws_ami.ubuntu.id
#   instance_type  = var.instance_type
#   security_group = aws_security_group.frontend.id
#   subnet         = module.vpc.public_subnet_ids[0]
#   key_name       = "joao-irene-useast1"
#   tags           = { Name = "frontend-joao-irene" }
# }

# module "backend" {
#   source         = "./modules/instance"
#   has_public_ip  = false
#   ami            = data.aws_ami.ubuntu.id
#   instance_type  = var.instance_type
#   security_group = aws_security_group.backend.id
#   subnet         = module.vpc.private_subnet_ids[0]
#   key_name       = "joao-irene-useast1"
#   tags           = { Name = "backend-joao-irene" }
# }

# module "database" {
#   source         = "./modules/instance"
#   has_public_ip  = false
#   ami            = data.aws_ami.ubuntu.id
#   instance_type  = var.instance_type
#   security_group = aws_security_group.database.id
#   subnet         = module.vpc.private_subnet_ids[1]
#   key_name       = "joao-irene-useast1"
#   tags           = { Name = "database-joao-irene" }
# }