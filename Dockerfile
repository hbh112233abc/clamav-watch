FROM alpine:latest

# 安装依赖
RUN apk add --no-cache \
    inotify-tools \
    clamav \
    clamav-libunrar \
    bash \
    tzdata

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建必要目录
RUN mkdir -p /scans /quarantine /var/log

# 复制监控脚本
COPY scan.sh /usr/local/bin/scan.sh
RUN chmod +x /usr/local/bin/scan.sh

# 初始化病毒库（构建时更新一次）
RUN freshclam

# 设置容器启动命令
ENTRYPOINT ["/usr/local/bin/scan.sh"]
