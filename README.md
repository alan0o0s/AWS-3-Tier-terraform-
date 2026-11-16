# AWS 3-Tier Highly Available Web Application Infrastructure

Terraform project that provisions a production-style, highly available 3-tier
web application environment on AWS: a public-facing load balancer tier, an
auto-scaling private application tier, and a private database tier.

## Project Overview

This project stands up a **working** 3-tier application, not just infrastructure
sitting next to an unused database:

- A VPC spanning 2+ Availability Zones with public, private-application, and
  private-database subnets
- An Internet Gateway and one NAT Gateway per AZ for outbound-only private traffic
- An Application Load Balancer distributing HTTP traffic to a Target Group
- An Auto Scaling Group of EC2 instances running a **Flask application that
  connects to the private RDS database**, initializes a `users` table with
  sample data, and exposes CRUD + health endpoints - scaled by a CPU-based
  target tracking policy
- A private, encrypted RDS database (PostgreSQL by default, MySQL supported),
  reachable only from the application tier
- IAM roles using SSM Session Manager instead of open SSH
- CloudWatch alarms for CPU, ALB, target health, and RDS metrics
- A generated SSH key pair (optional fallback; SSM is preferred)

### The Application

Each EC2 instance runs a small Flask app (via gunicorn on port 80) at
`/opt/app/app.py`, installed by `user-data.sh`. On startup it connects to RDS,
creates a `users` table if it doesn't exist, and seeds it with 5 sample rows.

| Endpoint | Method | Purpose |
|---|---|---|
| `/` | GET | HTML page showing hostname, instance ID, AZ, environment, and live DB connection status |
| `/health` | GET | App-only liveness check (always 200 if the process is up) - **used by the ALB Target Group health check** |
| `/db-health` | GET | JSON: real DB connectivity check + user count (200 if connected, 503 if not) |
| `/users` | GET | JSON list of all users from the database |
| `/users` | POST | Insert a user: `{"name": "...", "email": "..."}` |

`/health` is deliberately separate from `/db-health`: the Target Group checks
app liveness only, so a healthy-but-DB-degraded instance isn't yanked out of
rotation while you're debugging the database.

## Architecture

```text
                              Internet
                                 |
                          Internet Gateway
                                 |
                  +--------------+---------------+
                  |                              |
           Public Subnet (AZ-A)           Public Subnet (AZ-B)
             NAT Gateway A                  NAT Gateway B
                  |                              |
                  +--------------+---------------+
                                 |
                     Application Load Balancer (:80)
                                 |
                            Target Group
                            /          \
             Private App Subnet A   Private App Subnet B
                  EC2 (ASG)              EC2 (ASG)
                     \                      /
                      \                    /
                    Private DB Subnet A/B
                            RDS (Multi-AZ)
```

Traffic flow: `Internet -> IGW -> ALB -> Target Group -> ASG/EC2 -> RDS`.
Outbound-only flow for private instances: `EC2 -> NAT Gateway -> IGW -> Internet`.

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC, Subnets, Route Tables | Network isolation across 3 tiers |
| Internet Gateway | Public Internet access for the public subnets |
| NAT Gateway (per AZ) | Outbound-only Internet access for private subnets |
| Application Load Balancer | Distributes HTTP traffic across AZs |
| Target Group | Health-checks and routes to EC2 instances |
| Launch Template + Auto Scaling Group | Runs and scales the web tier |
| EC2 (Amazon Linux 2023 + nginx) | Application servers |
| RDS (PostgreSQL/MySQL) | Managed relational database, Multi-AZ |
| IAM Role + Instance Profile | Grants SSM + minimal CloudWatch permissions |
| CloudWatch Alarms | CPU, RDS CPU/connections visibility |
| Systems Manager (SSM) | Shell access to instances without SSH |
| TLS provider | Generates the local SSH key pair |

## Folder Structure

```text
aws-3tier-terraform/
├── main.tf                  # Wires all modules together
├── providers.tf             # AWS/TLS/random provider configuration
├── versions.tf              # Terraform + provider version pins, backend block
├── variables.tf             # Root input variables
├── locals.tf                # Naming prefix, common tags, db port
├── outputs.tf                # Root outputs (ALB DNS, RDS endpoint, etc.)
├── terraform.tfvars.example # Example values - copy to terraform.tfvars
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT, route tables
│   ├── security-groups/     # ALB / App / DB security groups
│   ├── alb/                 # Load balancer, target group, listener
│   ├── compute/             # Key pair, launch template, ASG, scaling policy
│   ├── rds/                 # DB subnet group, parameter group, RDS instance
│   └── iam/                 # EC2 role, SSM policy, instance profile
├── scripts/
│   ├── deploy.sh            # init -> fmt -> validate -> plan -> apply
│   └── destroy.sh           # Guarded terraform destroy
└── keys/                    # Generated private key lands here (gitignored)
```

## Prerequisites

- An AWS account with permissions to create VPC, EC2, ELBv2, RDS, and IAM resources
- [AWS CLI](https://docs.aws.amazon.com/cli/) configured (`aws configure`) or
  equivalent credentials (env vars, SSO, or an assumed role)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.7.0
- Git

Terraform authenticates to AWS using the standard credential chain (env vars,
`~/.aws/credentials`, instance/role credentials, or SSO). No credentials are
stored in this repository.

## Deployment

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed (do NOT put db_password here for real use)

# 2. Provide the DB password out-of-band
export TF_VAR_db_password="a-strong-password-here"

# 3. Standard workflow
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Or use the wrapper script, which runs the same steps with a confirmation prompt:

```bash
./scripts/deploy.sh
```

## Verification

```bash
# Get the ALB DNS name
terraform output alb_dns_name
ALB=$(terraform output -raw alb_dns_name)

# App page - shows hostname/instance/AZ AND live DB connection status
curl http://$ALB/

# App liveness (what the Target Group actually checks)
curl http://$ALB/health

# Real database connectivity proof
curl http://$ALB/db-health
# {"database_engine": "postgres", "database_connection": "SUCCESS", "user_count": 5, ...}

# List the seeded sample users
curl http://$ALB/users

# Insert a new user (CRUD write path)
curl -X POST http://$ALB/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Nour", "email": "nour@example.com"}'
```

A `database_connection: "SUCCESS"` response from `/db-health` proves the full
chain: `Internet -> ALB -> Target Group -> ASG -> EC2 -> RDS` is actually
working, not just provisioned.

Refresh `/` multiple times — the returned hostname/instance ID should change
as the ALB distributes requests across instances in both AZs, while
`user_count` stays consistent because every instance is reading the same
shared RDS database.

- **Target Group health**: EC2 console -> Target Groups -> Targets tab, or
  `aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)`
- **Auto Scaling Group**: EC2 console -> Auto Scaling Groups -> `terraform output autoscaling_group_name`
- **CloudWatch**: CloudWatch console -> Alarms, look for `<project>-high-cpu` / `<project>-low-cpu`
- **RDS**: RDS console, or `terraform output rds_endpoint`

### Proving RDS Is Not Publicly Accessible

```text
Internet ─────X────→ RDS   (blocked - RDS has no public IP and the DB
                             security group only allows the App security
                             group as a source)
EC2 ───────────────→ RDS :5432   (allowed)
```

Attempting to connect to the RDS endpoint from outside the VPC (e.g. your own
laptop) will simply time out — there is no route to it and no security group
rule permitting it. The app's successful `/db-health` response, reachable
only via the ALB, is what demonstrates the "allowed" path instead.

### Load Testing / Auto Scaling Test

1. Connect to an instance via SSM (see below) or SSH.
2. Generate CPU load:
   ```bash
   sudo dnf install -y stress-ng
   stress-ng --cpu 2 --timeout 300s
   ```
3. Watch CloudWatch: once average ASG CPU exceeds the `cpu_target` (default
   50%) for a sustained period, the target tracking policy launches
   additional instances. This can take a few minutes due to metric
   aggregation, alarm evaluation periods, and instance warm-up.
4. **Scale-in**: once load stops and CPU drops back down, the same policy
   removes instances after its cooldown, converging back toward
   `desired_capacity`/`min_size`.

## How CPU-Based Auto Scaling Works

```text
CPU > cpu_target (50%)  --> target tracking policy scales OUT (adds instances)
CPU well below target   --> target tracking policy scales IN  (removes instances)
```

This project uses an `aws_autoscaling_policy` with
`policy_type = "TargetTrackingScaling"` and the predefined metric
`ASGAverageCPUUtilization`, targeting `var.cpu_target` (default 50%). AWS
manages both scale-out and scale-in automatically around that target — this
is the recommended approach over hand-rolled step-scaling alarms. Two
CloudWatch alarms (`high-cpu` / `low-cpu`) are also created purely for
visibility into when thresholds are crossed; they do not themselves trigger
scaling actions.

## How the Target Group Connects the ALB to the ASG

The `alb` module creates the Target Group and Listener; the `compute` module's
`aws_autoscaling_group` resource is given that Target Group's ARN via
`target_group_arns`. The ASG then automatically registers new instances at
launch and deregisters them on termination — instances are never manually
attached.

## How the Key Pair Is Created

The `compute` module uses the `tls_private_key` resource to generate a 4096-bit
RSA key pair locally, registers the public half as an `aws_key_pair` in AWS,
and writes the private half to `keys/<project>-<env>-key.pem` (mode `0400`)
via `local_sensitive_file`. This file — and the entire `keys/` directory — is
excluded from Git via `.gitignore`.

## SSH / SSM Access

**Preferred: SSM Session Manager** (no open SSH port required):

```bash
aws ssm start-session --target <instance-id>
```

This works because the EC2 instance role includes
`AmazonSSMManagedInstanceCore` and the instances have outbound Internet
access via NAT to reach the SSM endpoints.

**Optional: SSH**, only if `enable_ssh = true` and `ssh_allowed_cidr` is set to
your IP:

```bash
ssh -i keys/<project>-<env>-key.pem ec2-user@<instance-private-ip>
```

Note the application instances are in private subnets with no public IP, so
direct SSH from the Internet is not possible even with `enable_ssh = true` —
you'd need a bastion host or SSM port forwarding. SSM is the supported path.

## Remote State Backend

This project ships with the S3 backend block commented out in `versions.tf`,
since Terraform can't create its own backend resources before initialization.
To use a remote backend:

1. Create the S3 bucket (with versioning + encryption) and DynamoDB table
   (partition key `LockID`) manually or via a small bootstrap Terraform
   config, in a *different* state than this project.
2. Uncomment and fill in the `backend "s3" {}` block in `versions.tf`.
3. Run `terraform init -migrate-state`.

## Destroy

```bash
terraform destroy
```

or:

```bash
./scripts/destroy.sh
```

**Important**:
- If `enable_deletion_protection = true` (the default) on RDS, destroy will
  fail until you set it to `false` and re-apply, or disable protection
  manually first.
- If `skip_final_snapshot = false` (the default), RDS will create a final
  snapshot on destroy, which persists (and costs money) after `destroy`
  completes — delete it manually from the RDS console if not needed.

## Security

- Application EC2 instances and RDS have **no public IP** and are not
  reachable from the Internet.
- Security groups follow least privilege: Internet -> ALB (80) -> App (80) ->
  DB (5432/3306), each restricted to the security group in front of it, not
  open CIDRs.
- IAM: the EC2 instance role grants only `AmazonSSMManagedInstanceCore` plus a
  narrow CloudWatch/logs policy — no `AdministratorAccess`.
- RDS storage is encrypted at rest; EBS root volumes are encrypted.
- IMDSv2 is enforced on instances (`http_tokens = "required"`).
- No secrets are committed to Git: `terraform.tfvars`, `*.tfstate`, and
  `keys/` are all gitignored. `db_password` is marked `sensitive = true`.
- `sensitive = true` only prevents Terraform from printing the value in CLI
  output/logs — it is still stored in plaintext in the Terraform state file.
  For real production use, retrieve and rotate the database password via
  **AWS Secrets Manager** (or an equivalent secrets manager) rather than a
  Terraform variable, and ensure your state backend (e.g. S3) is encrypted
  and access-restricted.
- **How the app gets the DB password**: `user_data` writes it into
  `/opt/app/app.env` on each instance (mode `0600`, root-owned) which
  systemd loads as the Flask app's environment. This keeps the password out
  of process listings and out of the app's own logs/HTML output, but two
  caveats apply: (1) it is still visible in plaintext to anyone with
  `ec2:DescribeInstanceAttribute` permission on the account (EC2 stores
  `user_data` verbatim, just base64-encoded, not encrypted), and (2) it
  persists in Terraform state as noted above. For a hardened production
  setup, have the instance fetch the password from AWS Secrets Manager at
  boot (via the IAM role, with a `secretsmanager:GetSecretValue` policy
  scoped to that one secret) instead of receiving it through `user_data`.

## Cost Considerations

This project creates billable resources, notably:

- **NAT Gateways** (one per AZ) — hourly charge + data processing charge
- **Application Load Balancer** — hourly charge + LCU usage
- **RDS**, especially with `multi_az = true` — roughly doubles instance cost
- **EC2 instances** in the Auto Scaling Group
- **EBS volumes** and **Elastic IPs** attached to NAT Gateways

**Destroy resources after testing if you don't need them running.** For a
short-lived demo, consider `multi_az = false` and a smaller `max_size` to
reduce cost, and remember RDS final snapshots persist after `destroy` unless
removed manually.
