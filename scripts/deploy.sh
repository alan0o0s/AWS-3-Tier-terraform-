#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Convenience wrapper around the standard Terraform deployment workflow.
# Run from the project root: ./scripts/deploy.sh
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f terraform.tfvars ]; then
  echo "terraform.tfvars not found."
  echo "Copy terraform.tfvars.example to terraform.tfvars and fill in values first."
  echo "Remember: do NOT put db_password in terraform.tfvars for real use -"
  echo "export TF_VAR_db_password instead."
  exit 1
fi

echo "==> terraform init"
terraform init

echo "==> terraform fmt -recursive"
terraform fmt -recursive

echo "==> terraform validate"
terraform validate

echo "==> terraform plan"
terraform plan -out=tfplan

read -r -p "Apply this plan? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "==> terraform apply"
  terraform apply tfplan
else
  echo "Aborted. No changes applied."
  rm -f tfplan
  exit 0
fi

rm -f tfplan

echo
echo "==> Deployment complete. Key outputs:"
terraform output
