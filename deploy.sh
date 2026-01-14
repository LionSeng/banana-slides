#!/bin/bash

# Banana Slides 生产环境快速部署脚本
# 适用于 Ubuntu 22.04 LTS

set -e

echo "========================================"
echo "  Banana Slides 生产环境部署脚本"
echo "========================================"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 步骤 1：更新系统
echo -e "${GREEN}[1/8]${NC} 更新系统..."
apt update && apt upgrade -y

# 步骤 2：安装必要工具
echo -e "${GREEN}[2/8]${NC} 安装必要工具..."
apt install -y curl git docker.io docker-compose nginx certbot python3-certbot-nginx ufw

# 步骤 3：启动 Docker 服务
echo -e "${GREEN}[3/8]${NC} 启动 Docker 服务..."
systemctl start docker
systemctl enable docker

# 步骤 4：克隆项目
echo -e "${GREEN}[4/8]${NC} 克隆项目..."
if [ ! -d "banana-slides" ]; then
    git clone https://github.com/Anionex/banana-slides.git
    cd banana-slides
else
    echo "项目已存在，跳过克隆"
    cd banana-slides
    git pull
fi

# 步骤 5：配置环境变量
echo -e "${GREEN}[5/8]${NC} 配置环境变量..."
if [ ! -f ".env" ]; then
    cp .env.production.example .env
    echo -e "${YELLOW}请编辑 .env 文件，配置以下关键信息：${NC}"
    echo "  - SECRET_KEY: 运行 python -c \"import secrets; print(secrets.token_hex(32))\" 生成"
    echo "  - GOOGLE_API_KEY: 填入你的 Google API Key"
    echo "  - CORS_ORIGINS: 设置为你的域名"
    echo "  - POSTGRES_PASSWORD: 设置强密码"
    echo ""
    read -p "是否现在编辑 .env 文件？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nano .env
    fi
else
    echo ".env 文件已存在，跳过"
fi

# 步骤 6：配置 Nginx
echo -e "${GREEN}[6/8]${NC} 配置 Nginx..."
read -p "请输入你的域名（例如：example.com）: " DOMAIN

if [ -n "$DOMAIN" ]; then
    # 创建 Nginx 配置
    cat > /etc/nginx/sites-available/banana-slides <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    client_max_body_size 100M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
}
EOF

    # 启用配置
    ln -sf /etc/nginx/sites-available/banana-slides /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # 测试配置
    nginx -t
    systemctl reload nginx

    # 步骤 7：配置 SSL
    echo -e "${GREEN}[7/8]${NC} 配置 SSL 证书..."
    read -p "是否配置 SSL 证书？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        certbot --nginx -d $DOMAIN -d www.$DOMAIN

        # 配置自动续期
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet") | crontab -
    fi
fi

# 步骤 8：启动应用
echo -e "${GREEN}[8/8]${NC} 启动应用..."
docker compose -f docker-compose.prod.yml up -d

# 步骤 9：配置防火墙
echo -e "${GREEN}[9/8]${NC} 配置防火墙..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 步骤 10：配置备份
echo -e "${GREEN}[10/8]${NC} 配置自动备份..."
chmod +x backup.sh
mkdir -p /backups/banana-slides
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup.sh") | crontab -

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "应用访问地址："
if [ -n "$DOMAIN" ]; then
    echo "  - 前端: http://$DOMAIN"
    echo "  - 后端: http://$DOMAIN/api"
else
    echo "  - 前端: http://$(curl -s ifconfig.me):3000"
    echo "  - 后端: http://$(curl -s ifconfig.me):5000/api"
fi
echo ""
echo "管理工具："
echo "  - Portainer: http://$(curl -s ifconfig.me):9000"
echo ""
echo "常用命令："
echo "  - 查看日志: docker compose -f docker-compose.prod.yml logs -f"
echo "  - 停止服务: docker compose -f docker-compose.prod.yml down"
echo "  - 重启服务: docker compose -f docker-compose.prod.yml restart"
echo ""
echo -e "${YELLOW}注意事项：${NC}"
echo "  1. 请确保已正确配置 .env 文件中的 API Key"
echo "  2. 请确保域名 DNS 已正确解析到服务器 IP"
echo "  3. 建议定期检查备份文件"
echo "  4. 建议配置监控和告警"
echo ""
echo -e "${GREEN}祝您使用愉快！🎉${NC}"
