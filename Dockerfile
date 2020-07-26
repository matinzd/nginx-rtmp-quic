FROM alpine:latest

LABEL maintainer "Matin Zadehdolatabad <zadehdolatabad@gmail.com>"

ENV NGINX_VERSION nginx-1.16.1

RUN \
    build_packages="openssl-dev cargo cmake linux-headers pcre-dev git zlib-dev wget build-base" && \
    runtime_packages="ca-certificates pcre zlib libaio openssl" && \
    apk --update add ${build_packages} ${runtime_packages} && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone https://github.com/arut/nginx-rtmp-module.git && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch && \
    ./configure \
        --prefix=/etc/nginx \
        --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-openssl=../quiche/deps/boringssl \
        --with-quiche=../quiche \
        --with-cc-opt="-Wimplicit-fallthrough=0" \
        --add-module=../nginx-rtmp-module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-threads \
        --with-http_auth_request_module \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx && \
    make && \
    make install && \
    apk del ${build_packages} && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/log/nginx"]

WORKDIR /etc/nginx

CMD ["nginx", "-g", "daemon off;"]
