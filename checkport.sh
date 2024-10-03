#!/bin/bash
set -e

# Mở cổng 8180 trong Security Group nếu chưa mở
echo "Kiểm tra và mở cổng 8180 trong Security Group nếu cần..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

if ! aws ec2 describe-security-groups --group-ids $SG_ID --query "SecurityGroups[0].IpPermissions[?FromPort==\`8180\`]" --output text | grep -q 8180; then
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8180 --cidr 0.0.0.0/0
    echo "Đã mở cổng 8180 cho tất cả IP."
else
    echo "Cổng 8180 đã được mở."
fi

# Mở cổng 30008 trong Security Group nếu chưa mở
echo "Kiểm tra và mở cổng 30008 trong Security Group nếu cần..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

if ! aws ec2 describe-security-groups --group-ids $SG_ID --query "SecurityGroups[0].IpPermissions[?FromPort==\`30008\`]" --output text | grep -q 30008; then
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 30008 --cidr 0.0.0.0/0
    echo "Đã mở cổng 30008 cho tất cả IP."
else
    echo "Cổng 30008 đã được mở."
fi