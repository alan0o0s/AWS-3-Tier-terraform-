#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Convenience wrapper to tear down all infrastructure created by this project.
# Run from the project root: ./scripts/destroy.sh
#
# NOTE: If enable_deletion_protection = true (the default) on the RDS
# instance, this will fail until you set it to false and re-apply, or disable
# it manually in the AWS console first.
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."

echo "WARNING: This will destroy ALL resources managed by this Terraform project,"
echo "including the RDS database (see terraform.tfvars for snapshot settings)."
read -r -p "Type 'destroy' to continue: " confirm

if [[ "$confirm" != "destroy" ]]; then
  echo "Aborted."
  exit 0
fi

terraform plan -destroy -out=tfdestroyplan
echo
read -r -p "Proceed with the destroy plan above? [y/N] " final_confirm
if [[ "$final_confirm" =~ ^[Yy]$ ]]; then
  terraform apply tfdestroyplan
else
  echo "Aborted. No changes applied."
fi

rm -f tfdestroyplan
