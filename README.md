# ClamAV-Watch

基于 Docker 的实时文件监控与杀毒解决方案。使用 ClamAV 杀毒引擎配合 inotify-tools 实现对指定目录的实时文件扫描，发现病毒文件自动移至隔离区。

## 功能特性

- **实时监控**：使用 `inotifywait` 监控指定目录的文件变化
- **自动扫描**：新文件创建或移入时自动进行病毒扫描
- **自动隔离**：检测到病毒文件时自动移动到隔离区
- **病毒库更新**：后台自动更新病毒库（每天一次）
- **可选全量扫描**：支持容器启动时对现有文件进行全量扫描
- **资源限制**：配置了 CPU 和内存限制，防止资源滥用
- **日志记录**：完整的扫描日志，支持日志轮转

## 项目结构

```
clamav-watch/
├── docker-compose.yaml  # Docker Compose 配置
├── Dockerfile           # 容器镜像构建文件
├── scan.sh              # 主监控脚本
├── quarantine/          # 隔离区目录（自动创建）
├── logs/                # 日志目录（自动创建）
└── README.md            # 项目文档
```

## 快速开始

### 1. 启动服务

```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 2. 配置扫描目录

默认监控 `/var/www/uploads` 目录。如需修改，编辑 `docker-compose.yaml` 中的卷挂载配置：

```yaml
volumes:
  # 将宿主机目录挂载到容器 /scans
  - /your/path:/scans
```

### 3. 配置参数

通过环境变量自定义配置：

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `TZ` | `Asia/Shanghai` | 时区设置 |
| `SCAN_DELAY` | `0.2` | 扫描延迟（秒），确保文件写入完成 |
| `SCAN_AT_STARTUP` | `1` | 启动时是否全量扫描（1=是，0=否） |

## 目录说明

- **`/scans`**：监控目录，存放待扫描文件
- **`/quarantine`**：隔离区目录，存放检测到的病毒文件
- **`/var/log`**：日志目录，包含扫描日志

## 使用示例

### 上传文件扫描

```bash
# 通过 Web 服务上传文件到监控目录
cp malicious_file.exe /var/www/uploads/

# 检查日志确认扫描结果
docker-compose logs | grep malicious_file.exe
```

### 手动全量扫描

```bash
# 进入容器
docker exec -it clamav-watch /bin/bash

# 执行全量扫描
clamscan --recursive --infected --move=/quarantine /scans
```

### 临时扫描宿主机目录

不想持续监控，只想临时扫描宿主机上的某个目录？使用 `docker run` 临时启动容器，挂载目标目录即可：

```bash
# 扫描宿主机上的指定目录
docker run --rm \
  -v /your/scan/path:/scans \
  -v $(pwd)/quarantine:/quarantine \
  clamav-watch clamscan -r --infected --move=/quarantine /scans
```

参数说明：
- `--rm`：扫描完成后自动删除容器
- `-v /your/scan/path:/scans`：将宿主机目录挂载到容器内 `/scans`
- `-v $(pwd)/quarantine:/quarantine`：挂载隔离区目录保存病毒文件

### docker exec 临时扫描

使用 `docker exec` 直接在容器内执行临时扫描命令，无需进入容器交互式 shell：

```bash
# 扫描单个文件
docker exec clamav-watch clamscan /scans/example.pdf

# 扫描指定目录（显示详细信息）
docker exec clamav-watch clamscan -r -i /scans

# 扫描并移动病毒文件到隔离区
docker exec clamav-watch clamscan --move=/quarantine /scans

# 扫描后删除感染文件（危险操作，谨慎使用）
docker exec clamav-watch clamscan --remove=yes /scans

# 生成扫描报告到日志文件
docker exec clamav-watch clamscan -r /scans >> scan-report.txt 2>&1
```

常用参数说明：

| 参数 | 说明 |
|------|------|
| `-r` | 递归扫描子目录 |
| `-i` | 仅显示感染文件信息 |
| `--move=目录` | 移动病毒文件到指定隔离区 |
| `--remove=yes` | 删除感染文件 |
| `--no-summary` | 禁用统计摘要输出 |

### 更新病毒库

```bash
docker exec clamav-watch freshclam
```

## 日志示例

```
[Thu Apr  9 16:00:00 CST 2026] ClamAV Real-time Scanner Started
[Thu Apr  9 16:00:00 CST 2026] Monitoring: /scans
[Thu Apr  9 16:00:05 CST 2026] ✅ CLEAN: /scans/document.pdf
[Thu Apr  9 16:01:30 CST 2026] 🦠 VIRUS DETECTED: /scans/virus.exe -> Eicar.Test.File (moved to quarantine)
```

## 注意事项

1. **临时文件过滤**：脚本会自动跳过 `.part`、`.tmp`、`.swp`、`.crdownload` 等临时文件
2. **隐藏文件过滤**：以 `.` 开头的隐藏文件不会被扫描
3. **权限要求**：确保挂载目录有足够的读取权限
4. **病毒库更新**：首次构建时会下载病毒库（约 300MB），请确保网络连接稳定

## 资源要求

- **CPU**：建议 2 核心
- **内存**：建议至少 512MB（ClamAV 运行需要）
- **磁盘**：病毒库约 300MB + 隔离区空间

## 扩展功能

如需启用邮件告警功能，可在 `scan.sh` 中取消注释相关代码并配置邮件服务：

```bash
# 取消注释以下行并配置收件人
# echo "Virus detected: $VIRUS in $FILE" | mail -s "ClamAV Alert" admin@example.com
```

## License

MIT License
