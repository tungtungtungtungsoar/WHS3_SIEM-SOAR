#!/bin/bash
# Usage: forensic_isolation.sh <INFECTED_PRIVATE_IP>

set -e

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
INFECTED_PRIVATE_IP="$1"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

if [ -z "$INFECTED_PRIVATE_IP" ]; then
    echo "[ERROR] 감염 인스턴스의 Private IP가 필요합니다."
    exit 1
fi

echo "[INFO] 감염 인스턴스 Private IP: $INFECTED_PRIVATE_IP"

# 1. 감염 인스턴스 정보 추출
INSTANCE_DESC=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=private-ip-address,Values=$INFECTED_PRIVATE_IP")

INSTANCE_ID=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].InstanceId')
AMI_ID=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].ImageId')
INSTANCE_TYPE=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].InstanceType')
KEY_NAME=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].KeyName')
INSTANCE_NAME=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].Tags[] | select(.Key=="Name") | .Value')

if [[ -z "$INSTANCE_ID" || -z "$AMI_ID" || -z "$INSTANCE_TYPE" || -z "$KEY_NAME" || -z "$INSTANCE_NAME" ]]; then
    echo "[ERROR] 감염 인스턴스 정보 추출 실패"
    exit 1
fi

echo "[INFO] 감염 인스턴스 ID: $INSTANCE_ID"
echo "[INFO] AMI: $AMI_ID, TYPE: $INSTANCE_TYPE, KEY: $KEY_NAME, NAME: $INSTANCE_NAME"

# 중복 방지 포렌식 네이밍 (Name에 instance_name, description에 id와 name 모두)
FORENSIC_INSTANCE_NAME="forensic-${INSTANCE_NAME}-${TIMESTAMP}"

# 2. 감염 볼륨 스냅샷 생성
VOLUME_IDS=$(echo "$INSTANCE_DESC" | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId')
SNAPSHOT_IDS=()
for VOLUME_ID in $VOLUME_IDS; do
    SNAP_ID=$(aws ec2 create-snapshot \
        --region "$AWS_REGION" \
        --volume-id "$VOLUME_ID" \
        --description "Forensic snapshot from $INSTANCE_ID($INSTANCE_NAME) at $TIMESTAMP" \
        --tag-specifications "ResourceType=snapshot,Tags=[{Key=Forensic,Value=1},{Key=SourceInstance,Value=${INSTANCE_ID}},{Key=SourceName,Value=${INSTANCE_NAME}},{Key=Created,Value=${TIMESTAMP}}]" \
        --query "SnapshotId" --output text)
    echo "[INFO] 스냅샷 생성됨: $SNAP_ID"
    SNAPSHOT_IDS+=("$SNAP_ID")
done

# 2-1. 스냅샷 완료까지 대기
for SNAP_ID in "${SNAPSHOT_IDS[@]}"; do
    while true; do
        STATUS=$(aws ec2 describe-snapshots --region "$AWS_REGION" --snapshot-ids "$SNAP_ID" --query "Snapshots[0].State" --output text)
        if [ "$STATUS" = "completed" ]; then
            echo "[INFO] $SNAP_ID 완료"
            break
        else
            echo "[INFO] $SNAP_ID 진행 중..."
            sleep 10
        fi
    done
done

SNAPSHOT_ID_STR=$(IFS=' '; echo "${SNAPSHOT_IDS[*]}")

# 3. 운영 인스턴스 복구 (production terraform에서 리소스명 추출)
TFSTATE_PATH="/opt/terraform/production/terraform.tfstate"
if [ ! -f "$TFSTATE_PATH" ]; then
    echo "[ERROR] Terraform state 파일이 없습니다: $TFSTATE_PATH"
    exit 1
fi

RESOURCE_NAME=$(jq -r --arg NAME "$INSTANCE_NAME" '
  .resources[] | select(.type == "aws_instance") |
  select(.instances[].attributes.tags.Name == $NAME) |
  .name' $TFSTATE_PATH)

if [ -z "$RESOURCE_NAME" ]; then
    echo "[ERROR] Terraform에서 리소스 이름을 찾을 수 없습니다."
    exit 1
fi
echo "[INFO] 운영 인스턴스 리소스명: $RESOURCE_NAME"

# 4. 포렌식(격리) 인스턴스 생성
cd /opt/terraform/isolation
terraform init
terraform apply -auto-approve \
    -var="aws_region=$AWS_REGION" \
    -var="forensic_snapshot_ids=$SNAPSHOT_ID_STR" \
    -var="forensic_ami_id=$AMI_ID" \
    -var="forensic_instance_type=$INSTANCE_TYPE" \
    -var="forensic_key_name=$KEY_NAME" \
    -var="forensic_instance_name=$FORENSIC_INSTANCE_NAME" \
    -var="forensic_source_instance_id=$INSTANCE_ID" \
    -var="forensic_source_instance_name=$INSTANCE_NAME"

# 5. 운영 복구 인스턴스 재생성
cd /opt/terraform/production
terraform init
terraform taint aws_instance.${RESOURCE_NAME}
terraform apply -auto-approve -var="aws_region=$AWS_REGION" -target=aws_instance.${RESOURCE_NAME}

echo "[SUCCESS] 포렌식 격리, 운영 복구 모두 완료"
