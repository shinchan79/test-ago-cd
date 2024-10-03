#!/bin/bash
set -e

# Đọc thông tin cluster từ file cluster_info.env
source cluster_info.env

# Kiểm tra trạng thái cuối cùng của các dịch vụ
echo "Kiểm tra trạng thái cuối cùng của các dịch vụ:"
kubectl get pods -n keycloak
kubectl get svc -n keycloak

# Kiểm tra logs của Keycloak pod
echo "Logs của Keycloak pod:"
kubectl logs $(kubectl get pods -n keycloak -l app=keycloak -o name | head -n 1) -n keycloak

echo
echo "Để truy cập Keycloak Admin Console:"
echo "1. Mở trình duyệt và truy cập http://$PUBLIC_IP:30008"
echo "2. Nhấp vào 'Administration Console'"
echo "3. Đăng nhập với thông tin sau:"
echo "   Username: admin"
echo "   Password: admin"
echo
echo "Lưu ý: Nếu không thể truy cập ngay, vui lòng đợi vài phút và thử lại. Keycloak có thể cần thời gian để khởi động hoàn toàn."
