#!/usr/bin/env bash
set -euo pipefail

PROJECT=${TF_VAR_project_name:-ecs-terraform-lab}
ENV=${TF_VAR_environment:-dev}
REGION=${AWS_DEFAULT_REGION:-us-east-1}

OUTPUTS=$(terraform -chdir=infra output -json)

CLUSTER_NAME=$(echo "$OUTPUTS"   | jq -r '.cluster_name.value')
SERVICE_NAME=$(echo "$OUTPUTS"   | jq -r '.service_name.value')
LOG_GROUP=$(echo "$OUTPUTS"      | jq -r '.log_group_name.value')
EXEC_ROLE_ARN=$(echo "$OUTPUTS"  | jq -r '.task_execution_role_arn.value')
TASK_ROLE_ARN=$(echo "$OUTPUTS"  | jq -r '.task_role_arn.value')

echo "==> ECS Cluster: $CLUSTER_NAME"
STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" \
  | jq -r '.clusters[0].status')
[ "$STATUS" = "ACTIVE" ] || { echo "ERROR: cluster status $STATUS"; exit 1; }
echo "    OK (ACTIVE)"

echo "==> ECS Service: $SERVICE_NAME"
SVC_STATUS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
  --region "$REGION" | jq -r '.services[0].status')
[ "$SVC_STATUS" = "ACTIVE" ] || { echo "ERROR: service status $SVC_STATUS"; exit 1; }
echo "    OK (ACTIVE)"

echo "==> CloudWatch Log Group: $LOG_GROUP"
LG_COUNT=$(aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --region "$REGION" | jq '.logGroups | length')
[ "$LG_COUNT" -gt 0 ] || { echo "ERROR: log group not found"; exit 1; }
echo "    OK"

echo "==> IAM Execution Role: $EXEC_ROLE_ARN"
EXEC_NAME=$(basename "$EXEC_ROLE_ARN")
aws iam get-role --role-name "$EXEC_NAME" > /dev/null
echo "    OK"

echo "==> IAM Task Role: $TASK_ROLE_ARN"
TASK_NAME=$(basename "$TASK_ROLE_ARN")
aws iam get-role --role-name "$TASK_NAME" > /dev/null
echo "    OK"

echo "==> Todos los precheck pasaron."
