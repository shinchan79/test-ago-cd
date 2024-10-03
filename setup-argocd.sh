#!/bin/bash

set -e

# Lấy private IP của Cloud9 instance
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Lấy public IP của Cloud9 instance (cho mục đích truy cập từ bên ngoài)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

# Lấy Security Group ID
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

# Kiểm tra và thêm quy tắc bảo mật nếu chưa tồn tại
add_security_rule() {
    local port=$1
    if ! aws ec2 describe-security-groups --group-ids $SG_ID --query "SecurityGroups[0].IpPermissions[?FromPort==\`$port\`]" --output text | grep -q $port; then
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port $port --cidr 0.0.0.0/0
        echo "Đã thêm quy tắc cho cổng $port."
    else
        echo "Quy tắc cho cổng $port đã tồn tại."
    fi
}

# Tìm cổng trống
find_free_port() {
    local start_port=$1
    local port=$start_port
    while nc -z localhost $port 2>/dev/null; do
        port=$((port+1))
    done
    echo $port
}

# Tìm các cổng trống cho các dịch vụ
API_SERVER_PORT=$(find_free_port 6443) #7000
KEYCLOAK_PORT=$(find_free_port 8090)
ARGOCD_PORT=$(find_free_port 8070)

# Thêm quy tắc bảo mật cho các cổng mới
add_security_rule $API_SERVER_PORT
add_security_rule $KEYCLOAK_PORT
add_security_rule $ARGOCD_PORT

# Xóa cluster cũ nếu tồn tại
if kind get clusters | grep -q "^keycloak-argocd-cluster$"; then
    echo "Xóa cluster cũ..."
    kind delete cluster --name keycloak-argocd-cluster
fi

# Tạo cluster mới với cấu hình cập nhật
echo "Tạo cluster mới với API server port $API_SERVER_PORT..."
cat <<EOF | kind create cluster --name keycloak-argocd-cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "$PRIVATE_IP"
  apiServerPort: $API_SERVER_PORT
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30008
    hostPort: $KEYCLOAK_PORT
    listenAddress: "0.0.0.0"
  - containerPort: 30009
    hostPort: $ARGOCD_PORT
    listenAddress: "0.0.0.0"
EOF

# Cập nhật kubeconfig để sử dụng địa chỉ IP private và bỏ qua xác thực SSL
kubectl config set-cluster kind-keycloak-argocd-cluster --server=https://${PRIVATE_IP}:${API_SERVER_PORT} --insecure-skip-tls-verify=true
kubectl config set-context kind-keycloak-argocd-cluster --cluster=kind-keycloak-argocd-cluster
kubectl config use-context kind-keycloak-argocd-cluster

# Kiểm tra kết nối đến cluster
echo "Kiểm tra kết nối đến cluster..."
kubectl get nodes

# Kiểm tra và tạo namespace argocd nếu chưa tồn tại
if ! kubectl get namespace | grep -q "^argocd "; then
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    # Đợi ArgoCD sẵn sàng
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
else
    echo "Namespace argocd đã tồn tại."
fi

# Lấy mật khẩu ArgoCD
argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Expose ArgoCD service
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "targetPort": 8080, "nodePort": 30009}]}}'

echo "ArgoCD đã được triển khai thành công."
echo "Sử dụng username 'admin' và mật khẩu sau để đăng nhập vào ArgoCD:"
echo $argocd_password

echo "ArgoCD UI có thể truy cập tại http://$PUBLIC_IP:$ARGOCD_PORT"
echo "Kubernetes API server có thể truy cập tại https://$PRIVATE_IP:$API_SERVER_PORT"

# Lưu thông tin cần thiết cho script tiếp theo
echo "PRIVATE_IP=$PRIVATE_IP" > cluster_info.env
echo "PUBLIC_IP=$PUBLIC_IP" >> cluster_info.env
echo "KEYCLOAK_PORT=$KEYCLOAK_PORT" >> cluster_info.env
echo "ARGOCD_PORT=$ARGOCD_PORT" >> cluster_info.env
echo "API_SERVER_PORT=$API_SERVER_PORT" >> cluster_info.env

echo "Thông tin cluster đã được lưu vào file cluster_info.env"