#!/bin/bash

# Liệt kê tất cả các cluster Kind
clusters=$(kind get clusters)

if [ -z "$clusters" ]; then
    echo "Không có cluster Kind nào tồn tại."
else
    echo "Đang xóa các cluster Kind sau:"
    echo "$clusters"
    
    # Xóa từng cluster
    for cluster in $clusters; do
        echo "Đang xóa cluster: $cluster"
        kind delete cluster --name "$cluster"
    done
    
    echo "Tất cả các cluster Kind đã được xóa."
fi

# Kiểm tra xem còn cluster nào không
remaining_clusters=$(kind get clusters)
if [ -z "$remaining_clusters" ]; then
    echo "Không còn cluster Kind nào tồn tại."
else
    echo "Cảnh báo: Vẫn còn các cluster sau:"
    echo "$remaining_clusters"
fi