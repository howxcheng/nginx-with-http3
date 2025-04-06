# 第一阶段：构建阶段
FROM debian:stable-slim AS builder

# 设置构建环境变量
ENV BROTLI /usr/src/ngx_brotli
ENV NGINX /usr/src/nginx
ENV NGINX_VERSION 1.26.3
ENV BORINGSSL /usr/src/boringssl
ENV BORINGSSL_VERSION 0.20250311.0

# 安装构建依赖
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    clang \
    cmake \
    git \
    golang \
    libpcre2-dev \
    libbrotli-dev \
    libunwind-dev \
    llvm \
    ninja-build \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# 安装 BoringSSL
RUN git clone --single-branch --branch ${BORINGSSL_VERSION} https://boringssl.googlesource.com/boringssl $BORINGSSL && \
    cd ${BORINGSSL} && \
    cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ && \
    ninja -C build && \
    cp -f ${BORINGSSL}/build/crypto/libcrypto.* /usr/lib/ && \
    cp -f ${BORINGSSL}/build/ssl/libssl.* /usr/lib/ && \
    cp -rf ${BORINGSSL}/include/openssl /usr/include/openssl

# 安装 Brotli
RUN git clone --recurse-submodules https://github.com/google/ngx_brotli.git $BROTLI

# 获取并编译 Nginx
RUN git clone --single-branch --branch release-${NGINX_VERSION} https://github.com/nginx/nginx ${NGINX} && \
    cd ${NGINX} && \
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
    --add-module=${BROTLI} && \
    make && \
    make install

# 第二阶段：运行阶段
FROM debian:stable-slim

# 安装运行 Nginx 所需的最小依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends libbrotli1 && \
    rm -rf /var/lib/apt/lists/*

# 从构建阶段复制编译好的 Nginx 文件
COPY --from=builder /usr/lib/libcrypto.so /usr/lib/libcrypto.so
COPY --from=builder /usr/lib/libssl.so /usr/lib/libssl.so
COPY --from=builder /usr/include/openssl/ /usr/include/openssl/
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

# 创建 Nginx 用户和组并调整 Nginx 目录权限
RUN groupadd -g 1000 nginx && \
    useradd -g users -u 1000 nginx -s /sbin/nologin && \
    mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    mkdir -p /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx 

# 暴露端口
EXPOSE 80 443

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
