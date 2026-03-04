#!/bin/bash

exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- STARTING USER DATA ---"

# --- 1. MONTAGE DU DISQUE EBS ---
MOUNT_POINT="${mount_point}"
EXPECTED_SIZE="21474836480"

echo "Waiting for EBS volume to be attached..."
for i in {1..30}; do
    EBS_DEVICE=$(lsblk -dnbo NAME,SIZE | grep "$EXPECTED_SIZE" | awk '{print "/dev/"$1}')
    if [ -n "$EBS_DEVICE" ]; then
        echo "EBS volume found: $EBS_DEVICE"
        break
    fi
    sleep 1
done

if [ -n "$EBS_DEVICE" ]; then
    mkdir -p $MOUNT_POINT
    if [ -z "$(blkid $EBS_DEVICE)" ]; then
        mkfs -t ext4 $EBS_DEVICE
    fi
    mount $EBS_DEVICE $MOUNT_POINT
    if ! grep -qs "$MOUNT_POINT" /etc/fstab; then
        echo "$EBS_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" | tee -a /etc/fstab
    fi

    mkdir -p $MOUNT_POINT/docker_lib
    mkdir -p $MOUNT_POINT/containerd_lib
    
    mkdir -p /var/lib
    ln -s $MOUNT_POINT/docker_lib /var/lib/docker
    ln -s $MOUNT_POINT/containerd_lib /var/lib/containerd
    
    mkdir -p $MOUNT_POINT/{wp_data,db_data,prometheus_data,grafana_data,falco_data}
    chown -R ubuntu:ubuntu $MOUNT_POINT/wp_data $MOUNT_POINT/db_data
    chown -R 472:472 $MOUNT_POINT/grafana_data
    chown -R 65534:65534 $MOUNT_POINT/prometheus_data
    chown -R root:root $MOUNT_POINT/falco_data
else
    echo "ERROR: EBS volume not found. Docker will use root partition!"
fi

# --- 2. GESTION DU SWAP ---
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
fi

# --- 3. INSTALLATION DOCKER & NGINX ---
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg nginx
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl start docker
systemctl enable docker
systemctl start nginx
systemctl enable nginx
usermod -aG docker ubuntu

# --- 4. CONFIGURATION DU REVERSE PROXY (NGINX) ---
cat <<EOF > /etc/nginx/sites-available/wordpress
server {
    listen 80;
    server_name antonin-masson.org www.antonin-masson.org; 

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# --- 5. INSTALLATION TRIVY ---
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy linux-headers-$(uname -r)

# --- 6. CONFIGURATION DE L'APP ---
mkdir -p /home/ubuntu/wordpress
cat <<EOT > /home/ubuntu/wordpress/.env
WORDPRESS_DB_HOST=db
WORDPRESS_DB_USER=${db_user}
WORDPRESS_DB_PASSWORD=${db_password}
WORDPRESS_DB_NAME=${db_name}
MYSQL_ROOT_PASSWORD=${db_root_password}
MYSQL_DATABASE=${db_name}
MYSQL_USER=${db_user}
MYSQL_PASSWORD=${db_password}
MOUNT_POINT=${mount_point}
EOT


cat <<EOT > /home/ubuntu/wordpress/uploads.ini
file_uploads = On
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
EOT

# --- 7. CONFIGURATION DU MONITORING ---
mkdir -p /home/ubuntu/monitoring

cat <<EOF > /home/ubuntu/monitoring/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

cat <<EOT > /home/ubuntu/wordpress/docker-compose.yml
${docker_compose_content}
EOT

cat <<EOT > /home/ubuntu/monitoring/docker-compose.yml
${monitoring_compose_content}
EOT

# Lancement
chown -R ubuntu:ubuntu /home/ubuntu/wordpress
cd /home/ubuntu/wordpress
docker compose up -d

chown -R ubuntu:ubuntu /home/ubuntu/monitoring
cd /home/ubuntu/monitoring
docker compose up -d

echo "--- USER DATA FINISHED ---"
