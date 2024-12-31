# 第一阶段：构建阶段
FROM ubuntu:24.04 AS builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libpcre3-dev \
    zlib1g-dev \
    git \
    wget \
    curl \
    autoconf \
    libtool \
    pkg-config

# 获取并编译 Nginx
WORKDIR /nginx
RUN git clone https://github.com/nginx/nginx.git . && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    ./auto/configure \
    --prefix=/usr/local/nginx \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-cc-opt="-I$(pwd)/../quiche/include" \
    --with-ld-opt="-L$(pwd)/../quiche/lib" && \
    make && \
    make install

# 第二阶段：运行阶段
FROM ubuntu:24.04

# 安装运行 Nginx 所需的最小依赖
RUN apt-get update && apt-get install -y \
    libssl3t64 \
    libpcre3 \
    zlib1g \
    ca-certificates

# 从构建阶段复制编译好的 Nginx 文件
COPY --from=builder /usr/local/nginx /usr/local/nginx

# 配置 Nginx
# COPY nginx.conf /usr/local/nginx/conf/nginx.conf

# 暴露端口
EXPOSE 80 443

# 启动 Nginx
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
