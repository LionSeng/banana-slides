#!/bin/bash

# Banana Slides 自动备份脚本
# 用途：备份数据库和上传文件

BACKUP_DIR="/backups/banana-slides"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 创建备份目录
mkdir -p $BACKUP_DIR

echo "开始备份: $DATE"

# 备份数据库
echo "备份数据库..."
docker exec banana-slides-backend sqlite3 /app/backend/instance/database.db ".backup /tmp/backup.db"
docker cp banana-slides-backend:/tmp/backup.db $BACKUP_DIR/database_$DATE.db

# 备份上传文件
echo "备份上传文件..."
tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz ./uploads

# 备份环境变量
echo "备份环境变量..."
cp .env $BACKUP_DIR/env_$DATE.backup

# 删除过期备份
echo "清理 $RETENTION_DAYS 天前的备份..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

# 显示备份大小
echo "备份完成！"
du -sh $BACKUP_DIR/*

# 可选：上传到云存储（如阿里云 OSS）
# 使用前请先配置 OSS 工具
# ossutil cp $BACKUP_DIR/database_$DATE.db oss://your-bucket/backups/
# ossutil cp $BACKUP_DIR/uploads_$DATE.tar.gz oss://your-bucket/backups/

echo "备份脚本执行完成"
