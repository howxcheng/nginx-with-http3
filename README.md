## 镜像地址： [howxcheng/nginx-with-http3:latest](https://hub.docker.com/r/howxcheng/nginx-with-http3)

## 示例配置

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
      - ./crontab:/etc/crontab  # 支持计划任务
    restart: always
```

### crontab 示例配置

```js
0 0 * * * nginx -s reload
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
        # 响应头添加HTTP3支持声明
        add_header Alt-Svc 'h3=":443"; ma=86400'; # http3 1天缓存

        server_name www.showmeyoursite.com; # 服务器域名

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
    location / {
        # 基础代理设置
        server_name proxy1.showmeyoursite.com;
        proxy_pass http://test_backend;
        # 响应头添加HTTP3支持声明
        add_header Alt-Svc 'h3=":443"; ma=86400'; # http3 1天缓存

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

### webdav.conf 子配置文件示例

```js
server {
        listen 8080;
        server_name _;

        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/.htpasswd;
        # .htpasswd 写入用户名和加密过的密码，并设置权限600

        location / {
            # DAV 根目录
            root /var/www/webdav;
            # 启用 WebDAV 方法
            dav_methods PUT DELETE MKCOL COPY MOVE;
            # 启用 WebDAV Extension方法
            dav_ext_methods PROPFIND OPTIONS;
            # 自动创建上传文件的中间目录
            create_full_put_path on;
            # 新建文件和目录的权限：所有者/组可读写，其他只读
            dav_access user:rw group:rw all:r;

            autoindex on;
            client_max_body_size 0;

            # 强制 Basic 认证
            satisfy any;
        }
    }
```
