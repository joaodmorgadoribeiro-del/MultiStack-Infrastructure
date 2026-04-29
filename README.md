# MultiStack Infrastructure Project

A cloud-native voting application deployed on AWS using Docker, Terraform and Ansible.

---

## Architecture

```
                        ┌─────────────────────────────┐
                        │         INTERNET             │
                        └──────────────┬──────────────┘
                                       │
                        ┌──────────────▼──────────────┐
                        │     ALB (port 80)            │
                        │   /vote  ──►  /result        │
                        └──────┬───────────┬───────────┘
                               │           │
                    ┌──────────▼──┐   ┌────▼──────────┐
                    │  Vote EC2   │   │  Result EC2   │
                    │ Python/Flask│   │   Node.js     │
                    │  :5000      │   │   :4000       │
                    └──────┬──────┘   └────┬──────────┘
                           │               │
                    ┌──────▼───────────────▼───────────┐
                    │         Backend EC2               │
                    │    Redis :6379 + Worker .NET      │
                    └──────────────┬───────────────────┘
                                   │
                    ┌──────────────▼───────────────────┐
                    │         Database EC2              │
                    │         PostgreSQL :5432          │
                    └──────────────────────────────────┘

                    ┌──────────────────────────────────┐
                    │  Bastion Host (Public Subnet)     │
                    │  SSH gateway → all private EC2s  │
                    └──────────────────────────────────┘
```

---

## Run Locally with Docker Compose

The fastest way to run the full stack locally without any cloud infrastructure.

**Prerequisites:** Docker and Docker Compose installed.

```bash
# Clone the repository
git clone https://github.com/joaodmorgadoribeiro-del/MultiStack-Infrastructure.git
cd MultiStack-Infrastructure

# Start all services
docker compose up

# Run in background
docker compose up -d

# Stop all services
docker compose down
```

Once running:
- Vote app → http://localhost:5000
- Result app → http://localhost:4000

---

## Deploy to AWS from Scratch

**Prerequisites:** AWS CLI configured, Terraform installed, Ansible installed, SSH key pair created in AWS.

### Step 1 — Bootstrap remote state

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates the S3 bucket and DynamoDB table for remote state locking.

### Step 2 — Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (key_name, project_name, etc.)

terraform init
terraform plan
terraform apply
```

### Step 3 — Configure SSH

```bash
# Copy the generated SSH config to your local config
terraform output ssh_config >> ~/.ssh/config
chmod 600 ~/.ssh/config
```

### Step 4 — Deploy containers

```bash
cd ../ansible

# Update hosts file with Terraform outputs
terraform -chdir=../terraform output bastion_public_ip
terraform -chdir=../terraform output backend_private_ip
terraform -chdir=../terraform output database_private_ip

# Run the playbook
ansible-playbook -i hosts setup.yml
```

### Step 5 — Access the application

```bash
terraform -chdir=terraform output alb_dns_name
# Open http://<ALB_DNS>/vote and http://<ALB_DNS>/result
```

---

## Environment Variables

| Variable | Service | Description | Default |
|---|---|---|---|
| `REDIS_HOST` | Vote, Worker | Hostname or IP of the Redis instance | `redis` (local) |
| `DB_HOST` | Worker | Hostname or IP of the PostgreSQL instance | `db` (local) |
| `DB_USER` | Worker | PostgreSQL username | `postgres` |
| `DB_PASSWORD` | Worker | PostgreSQL password | `postgres` |
| `DB_NAME` | Worker | PostgreSQL database name | `postgres` |
| `PG_HOST` | Result | Hostname or IP of the PostgreSQL instance | `db` (local) |
| `PG_PORT` | Result | PostgreSQL port | `5432` |
| `PG_USER` | Result | PostgreSQL username | `postgres` |
| `PG_PASSWORD` | Result | PostgreSQL password | `postgres` |
| `PG_DATABASE` | Result | PostgreSQL database name | `postgres` |
| `POSTGRES_USER` | PostgreSQL | Database user | `postgres` |
| `POSTGRES_PASSWORD` | PostgreSQL | Database password | `postgres` |
| `POSTGRES_DB` | PostgreSQL | Database name | `postgres` |

---

## Terraform

Infrastructure provisioned as code using reusable modules.

**Root (`main.tf`)** — orchestrates all modules and defines Security Groups, ALB and remote state.

**`modules/vpc/`** — creates the VPC, public and private subnets, Internet Gateway, NAT Gateway and route tables.

**`modules/instance/`** — generic reusable EC2 module used for all 5 instances (bastion, vote, result, backend, database).

```bash
terraform init
terraform plan
terraform apply
```

Remote state stored in S3 with DynamoDB locking.

---

## Ansible

Playbooks deploy Docker containers to each EC2 instance via the Bastion Host using ProxyJump.

```
ansible/
├── hosts        # inventory with private IPs
├── setup.yml    # main playbook
└── ansible.cfg
```

```bash
ansible-playbook -i hosts setup.yml
```

**Playbook structure:**

- `hosts: all` — installs Docker on every instance
- `hosts: database` — runs PostgreSQL container
- `hosts: backend` — runs Redis + Worker containers
- `hosts: vote` — runs Vote app container
- `hosts: result` — runs Result app container

---

## Security

- All app instances in **private subnets** — no direct internet access
- **Bastion host** in public subnet as the only SSH entry point
- Security Groups follow least-privilege — each tier only allows traffic from the tier above it
- ALB is the only public entry point for HTTP traffic

---

## Known Limitations

- **No HTTPS** — the ALB currently runs on HTTP only. A production setup would require an ACM certificate and HTTPS listener.
- **Single AZ for app instances** — vote, result and backend run in the same AZ. A production setup would distribute across multiple AZs.
- **No Auto Scaling** — instances are fixed. Traffic spikes are not handled automatically.
- **Hardcoded credentials** — database passwords are defined as plain text in the Ansible playbook. A production setup would use AWS Secrets Manager or Ansible Vault.
- **No CI/CD** — deployments are triggered manually. A production setup would use GitHub Actions or a similar pipeline.
- **Bastion is a single point of failure** — if the bastion goes down, SSH access to all private instances is lost.

---

## Quick Start

```bash
# 1. Provision infrastructure
cd terraform
terraform apply

# 2. Update Ansible inventory with Terraform outputs
terraform output ssh_config >> ~/.ssh/config

# 3. Deploy containers
cd ../ansible
ansible-playbook -i hosts setup.yml
```

---

## Stack

| Layer | Technology |
|---|---|
| Containerisation | Docker |
| Infrastructure | Terraform (AWS) |
| Configuration | Ansible |
| Load Balancer | AWS ALB (path-based routing) |
| Frontend | Python/Flask (vote), Node.js (result) |
| Backend | .NET Worker, Redis |
| Database | PostgreSQL |

---

## Authors

**João Ribeiro**
Cloud & DevOps Engineer in Training
[![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/joaodmorgadoribeiro-del)

**Irene Romero**
Cloud & DevOps Engineer in Training
[![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/ireneromero95)

---


**João Ribeiro & Irene Romero** · Ironhack Cloud & DevOps Bootcamp · 2026
