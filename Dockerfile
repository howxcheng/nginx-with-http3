FROM alpine
LABEL org.opencontainers.image.source="https://github.com/howxcheng/nginx-with-script"

ARG http_proxy
ARG https_proxy
RUN apk add nginx python3 py3-yaml py3-requests
RUN sed -i 's/return 404;/root \/app\/html;/g' /etc/nginx/http.d/default.conf
RUN sed -i 's/80/35808/g' /etc/nginx/http.d/default.conf

VOLUME [ "/apps" ]
WORKDIR /apps
COPY apps /apps
RUN echo "0 */8 * * * /bin/ash /apps/run.sh" >>/etc/crontabs/root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]
