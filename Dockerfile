# 第一阶段：构建阶段
FROM debian:stable-slim AS builder

# 设置构建环境变量
ENV BROTLI_SOURCE=/usr/src/ngx_brotli
ENV NGINX_SOURCE=/usr/src/nginx
ENV NGINX_VERSION=1.28.0
ENV BORINGSSL_SOURCE=/usr/src/boringssl
ENV BORINGSSL_VERSION=0.20250415.0
ENV NGINX_DAV_SOURCE=/usr/src/nginx-dav-ext-module

# 安装构建依赖
RUN apt-get update && \
    apt-get full-upgrade -y && \
    apt-get install -y \
    build-essential \
    cmake \
    clang \
    llvm \
    ninja-build \
    git \
    golang \
    libpcre2-dev \
    libbrotli-dev \
    libunwind-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# 安装 BORINGSSL
RUN git clone --single-branch --branch ${BORINGSSL_VERSION} https://github.com/google/boringssl.git ${BORINGSSL_SOURCE} && \
    cd ${BORINGSSL_SOURCE} && \
    cmake -GNinja \
    -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ && \
    ninja -C build && \
    cp ${BORINGSSL_SOURCE}/build/crypto/libcrypto.so /usr/lib/ && \
    cp ${BORINGSSL_SOURCE}/build/ssl/libssl.so /usr/lib/ && \
    cp -r ${BORINGSSL_SOURCE}/include/openssl /usr/include/openssl

# 安装 Brotli
RUN git clone --single-branch https://github.com/google/ngx_brotli.git ${BROTLI_SOURCE} && \
    git clone --single-branch https://github.com/google/brotli.git ${BROTLI_SOURCE}/deps/brotli

# 安装 Dav extension
RUN git clone --single-branch https://github.com/arut/nginx-dav-ext-module.git ${NGINX_DAV_SOURCE}

# 获取并编译 Nginx
RUN git clone --single-branch --branch release-${NGINX_VERSION} https://github.com/nginx/nginx.git ${NGINX_SOURCE} && \
    cd ${NGINX_SOURCE} && \
    ./auto/configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-pcre-jit \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --with-cc-opt='-g -O2' \
    --add-module=${BROTLI_SOURCE} \
    --add-module=${NGINX_DAV_SOURCE} && \
    make -j$(nproc) && \
    make install

# 第二阶段：运行阶段
FROM debian:stable-slim

# 安装运行 Nginx 所需的最小依赖
RUN apt-get update && \
    apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends cron libbrotli1 libxml2 libxslt1.1 supervisor && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从构建阶段复制编译好的 Nginx 文件
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/libssl.so /usr/lib/libssl.so
COPY --from=builder /usr/lib/libcrypto.so /usr/lib/libcrypto.so

# 创建 Nginx 用户和组并调整 Nginx 目录权限
RUN groupadd -g 1000 nginx && \
    useradd -g users -u 1000 nginx -s /sbin/nologin && \
    mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    mkdir -p /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    mkdir -p /var/www/html && \
    chown -R nginx:nginx /var/www/html

# 复制配置文件和脚本
COPY entrypoint.sh /app/entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /app/entrypoint.sh && \
    echo "" > /etc/crontab && \
    chmod 644 /etc/crontab

# 暴露端口
EXPOSE 80 443

# 启动
ENTRYPOINT [ "/app/entrypoint.sh" ]
