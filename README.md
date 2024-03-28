# nginx-with-script
## 一个可以运行脚本的nginx docker镜像

#### 功能：

1、一个nginx服务器，根目录`/apps/html`

2、在`/apps`中可以放置文件，且每8小时运行一次`/apps/run.sh`脚本


#### 推荐用途

运行一个定时更新网页内容的nginx服务器
