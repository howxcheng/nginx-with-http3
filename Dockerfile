# 第一阶段：构建阶段
FROM debian:stable-slim AS builder

# 设置构建环境变量
ENV BROTLI /opt/ngx_brotli
ENV NGINX /opt/nginx
ENV NGINX_VERSION 1.26.3
ENV BORINGSSL /opt/boringssl
ENV BORINGSSL_INSTALL /usr/local/boringssl
ENV BORINGSSL_VERSION 0.20250311.0

# 安装构建依赖
RUN apt-get update && \
    apt-get install -y \
    wget \
    build-essential \
    curl \
    git \
    libpcre3-dev \
    libssl-dev \
    perl \
    zlib1g-dev \
    libxml2-dev \
    libgd-dev \
    libgeoip-dev \
    libxslt-dev \
    libperl-dev \
    libpcre2-dev \
    libzstd-dev \
    libbrotli-dev \
    libnghttp2-dev \
    libssl-dev \
    libjemalloc-dev \
    cmake \
    golang \
    llvm \
    clang \
    libunwind-dev \
    ninja-build && \
    rm -rf /var/lib/apt/lists/*

# 安装 BoringSSL
RUN git clone --single-branch --branch ${BORINGSSL_VERSION} https://boringssl.googlesource.com/boringssl $BORINGSSL && \
    cd ${BORINGSSL} && \
    cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ && \
    ninja -C build && \
    mkdir -p ${BORINGSSL_INSTALL}/lib && \
    cp -f ${BORINGSSL}/build/crypto/libcrypto.* ${BORINGSSL_INSTALL}/lib/ && \
    cp -f ${BORINGSSL}/build/ssl/libssl.* ${BORINGSSL_INSTALL}/lib/ && \
    cp -rf ${BORINGSSL}/include/ ${BORINGSSL_INSTALL}/include/

# 安装 Brotli
RUN git clone --recurse-submodules https://github.com/google/ngx_brotli.git $BROTLI

# 获取并编译 Nginx
RUN git clone --single-branch --branch release-${NGINX_VERSION} https://github.com/nginx/nginx ${NGINX} && \
    cd ${NGINX} && \
    ./auto/configure --prefix=/usr/local/nginx \
    --with-cc-opt=-O2 \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-http_slice_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_realip_module \
    --with-pcre-jit \
    --with-threads \
    --with-cc-opt="-I${BORINGSSL_INSTALL}/include" \
    --with-ld-opt="-L${BORINGSSL_INSTALL}/lib" \
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
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /usr/local/boringssl /usr/local/boringssl

RUN ln -s /usr/local/boringssl/lib/libssl.so /usr/lib/libssl.so && \
    ln -s /usr/local/boringssl/lib/libcrypto.so /usr/lib/libcrypto.so && \
    ln -s /usr/local/boringssl/include/openssl /usr/include/openssl

# 创建 Nginx 用户和组
RUN groupadd -g 1000 nginx && useradd -g users -u 1000 nginx -s /sbin/nologin

# 调整 Nginx 目录权限
RUN chown -R nginx:nginx /usr/local/nginx

# 创建 Nginx 日志目录
RUN mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx

# 暴露端口
EXPOSE 80 443

# 启动 Nginx
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
