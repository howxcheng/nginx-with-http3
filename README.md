# nginx-with-http3

支持 http3 的 nginx 镜像

### docker-compose.yaml 示例配置

```js
---
services:
  nginx:
    image: howxcheng/nginx-with-http3:latest
    container_name: nginx
    cap_add:
      - NET_ADMIN
    ports:
      - 80:80
      - 443:443
      - 443:443/udp
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./conf.d:/etc/nginx/conf.d
      - ./html:/var/www/html
    restart: always
```

### nginx.conf 示例配置

```js
# 确保防火墙开放UDP 443端口
user nginx nginx;

# 日志配置
error_log /dev/stderr;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    # 日志配置
    # access_log /dev/stdout;
    # 启用HTTP2支持
    http2 on;
    # 启用HTTP3支持
    http3 on;
    # 启用0-RTT支持
    ssl_early_data on;
    # 现代加密套件配置
    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers on;
    # 证书配置
    ssl_certificate /path/to/cert.pem; # 证书文件
    ssl_certificate_key /path/to/cert.key; # 证书文件

    sendfile on;
    # Brotli 压缩配置
    brotli on;
    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Gzip 压缩配置
    gzip on;
    server {
        # 监听 80 接口
        listen 80 default_server;
        # 跳转至 HTTPS
        return 301 https://$host$request_uri;
    }

    server {
        # 监听 443 接口
        listen 443 ssl reuseport default_server;
        # HTTP/3 & QUIC 监听
        listen 443 quic reuseport default_server;
        # 服务器域名
        server_name www.showmeyoursite.com;
        # 响应头添加HTTP3支持声明
        add_header Alt-Svc 'h3=":443"; ma=86400'; # http3 1天缓存

        location / {
            root /var/www/html;
            index index.html index.htm;
        }
    }

    # 引用网站
    include /etc/nginx/conf.d/*.conf;
}
```

### conf.d 子配置文件示例

```js
server {
    # 监听 443 接口
    listen 443 ssl;
    # HTTP/3 & QUIC 监听
    listen 443 quic;
    # 服务器域名
    server_name proxy1.showmeyoursite.com;
    # 响应头添加HTTP3支持声明
    add_header Alt-Svc 'h3=":443"; ma=86400'; # http3 1天缓存

    location / {
        # 基础代理设置
        proxy_pass http://test_backend;
        proxy_http_version 1.1;

        # 头部转发配置
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持核心配置
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
# 配置后端服务器
upstream test_backend {
    server 127.0.0.1:8080;
}
```
