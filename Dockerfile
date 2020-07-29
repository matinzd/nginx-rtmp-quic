FROM alpine:latest

LABEL maintainer "Matin Zadehdolatabad <zadehdolatabad@gmail.com>"
LABEL version="2.5"

ENV NGINX_VERSION=1.16.1
ENV LUAJIT_VERSION=2.1
ENV LUA_NGX_VERSION=0.10.17
ENV RTMP_NGX_VERSION=1.2.1
ENV NGX_DEVEL_KIT_VERSION=0.3.1

ARG NGINX_BUILD_OPTIONS="\
        --prefix=/etc/nginx \
        --build=\"quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)\" \
        --with-http_ssl_module \
        --with-http_secure_link_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-openssl=../quiche/deps/boringssl \
        --with-quiche=../quiche \
        --with-cc-opt=\"-Wimplicit-fallthrough=0\" \
        --with-ld-opt=\"-Wl,-rpath,/usr/lib\" \
        --add-module=../nginx-rtmp-module-${RTMP_NGX_VERSION} \
        --add-module=../lua-nginx-module-${LUA_NGX_VERSION} \
        --add-module=../ngx_devel_kit-${NGX_DEVEL_KIT_VERSION}} \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-threads \
        --with-http_auth_request_module \
        --with-http_realip_module \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx"

ARG DEV_PACKAGES="openssl-dev  cmake  pcre-dev git wget build-base luajit-dev"
ARG RUNTIME_PACKAGES="ca-certificates ffmpeg pcre zlib linux-headers libaio openssl zlib-dev cargo"

RUN \
    apk --update add ${DEV_PACKAGES} ${RUNTIME_PACKAGES} && \
    export LUAJIT_LIB=/usr/lib && \
    export LUAJIT_INC=/usr/lib/usr/include/luajit-${LUAJIT_VERSION} && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGX_VERSION}.tar.gz -O lua-nginx-module.tar.gz && tar -zxvf lua-nginx-module.tar.gz && \
    wget https://github.com/vision5/ngx_devel_kit/archive/v${NGX_DEVEL_KIT_VERSION}.tar.gz -O c.tar.gz && tar -zxvf ngx_devel_kit.tar.gz && \
    wget https://github.com/arut/nginx-rtmp-module/archive/v${RTMP_NGX_VERSION}.tar.gz -O nginx-rtmp-module.tar.gz && tar -zxvf nginx-rtmp-module.tar.gz && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    cd /tmp/src/nginx-${NGINX_VERSION} && \
    patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch && \
    ./configure ${NGINX_BUILD_OPTIONS} && \
    make j2 && \
    make install && \
    apk del ${DEV_PACKAGES} && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/log/nginx"]

WORKDIR /etc/nginx

CMD ["nginx", "-g", "daemon off;"]
