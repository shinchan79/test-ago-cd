#!/bin/bash
set -e

# Đọc thông tin cluster từ file cluster_info.env
source cluster_info.env

# Kiểm tra và tạo namespace keycloak nếu chưa tồn tại
if ! kubectl get namespace | grep -q "^keycloak "; then
    kubectl create namespace keycloak
else
    echo "Namespace keycloak đã tồn tại."
fi

# Clone hoặc pull repository nếu không tồn tại
if [ ! -d "test-ago-cd" ]; then
    git clone https://github.com/shinchan79/test-ago-cd.git
    cd test-ago-cd
else
    cd test-ago-cd
    git pull
fi

# Tạo file deployment.yaml cho Keycloak
cat << EOF > keycloak/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:24.0.5
          args: ["start-dev"]
          env:
            - name: KEYCLOAK_ADMIN
              value: "admin"
            - name: KEYCLOAK_ADMIN_PASSWORD
              value: "admin"
            - name: KC_PROXY
              value: "edge"
            - name: KC_HTTP_PORT
              value: "8180"
          ports:
            - name: http
              containerPort: 8180
          readinessProbe:
            httpGet:
              path: /realms/master
              port: 8180
EOF

# Tạo file service.yaml cho Keycloak với NodePort
cat << EOF > keycloak/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  type: NodePort  # Đảm bảo rằng kiểu là NodePort
  ports:
  - port: 8180
    targetPort: 8180
    nodePort: 30008  # Cổng mà bạn muốn sử dụng để truy cập
  selector:
    app: keycloak
EOF

# Kiểm tra thay đổi và commit nếu cần
git add .
if git status --porcelain | grep -q '^M'; then
    git commit -m "Update Keycloak Kubernetes manifests"
    git push
    echo "Đã cập nhật và push manifest Keycloak."
else
    echo "Không có thay đổi cần commit."
fi

# Kiểm tra xem ArgoCD Application đã tồn tại chưa
if kubectl get application keycloak -n argocd &> /dev/null; then
    echo "ArgoCD Application 'keycloak' đã tồn tại. Cập nhật application..."
    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/shinchan79/test-ago-cd.git
    targetRevision: HEAD
    path: keycloak
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
else
    echo "Tạo ArgoCD Application mới..."
    kubectl create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/shinchan79/test-ago-cd.git
    targetRevision: HEAD
    path: keycloak
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
fi

# Đồng bộ ArgoCD Application
echo "Đồng bộ ArgoCD Application..."
kubectl patch application keycloak -n argocd --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["ApplyOutOfSyncOnly=true"]}}}'

# Đợi Keycloak deployment được tạo hoặc cập nhật
echo "Đợi Keycloak deployment được tạo hoặc cập nhật..."
kubectl rollout status deployment/keycloak -n keycloak --timeout=300s

echo "Keycloak đã được triển khai thành công."
