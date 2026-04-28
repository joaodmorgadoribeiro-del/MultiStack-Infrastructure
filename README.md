# MultiStack Infrastructure Project

A cloud-native voting application deployed on AWS using Docker, Terraform and Ansible.

---

## Architecture

```
Internet → ALB (:80)
             ├── /vote   → Vote EC2 (Python/Flask)   ┐
             └── /result → Result EC2 (Node.js)      ├── Private Subnets
                                                      │
                           Backend EC2 (Redis + Worker .NET)
                           Database EC2 (PostgreSQL)  ┘

Bastion Host (Public Subnet) → SSH gateway to all private instances
```

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

**João Ribeiro & Irene Romero** · Ironhack Cloud & DevOps Bootcamp · 2026
