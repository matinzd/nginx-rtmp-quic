FROM alpine:latest

ENV NGINX_VERSION nginx-1.16.1

RUN apk --update add openssl-dev pcre-dev git zlib-dev wget build-base && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone https://github.com/arut/nginx-rtmp-module.git && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch && \
    ./configure \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-openssl=../quiche/deps/boringssl \
        --with-quiche=../quiche \
        --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
        --with-http_ssl_module \
        --add-module=../nginx-rtmp-module \
        --with-http_gzip_static_module \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx && \
    make && \
    make install && \
    apk del build-base && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/log/nginx"]

WORKDIR /etc/nginx

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
