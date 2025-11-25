FROM alpine:3.22.2

LABEL org.opencontainers.image.authors="alexey.zolotareff@gmail.com"
LABEL org.opencontainers.image.description="Network multitool with various debugging utilities"

EXPOSE 80 443 1180 11443

# Install some tools in the container and generate self-signed SSL certificates.
# Packages are listed in alphabetical order, for ease of readability and ease of maintenance.
RUN apk update \
    && apk add --no-cache \
                bash bind-tools busybox-extras curl git \
                iproute2 iputils jq mtr \
                net-tools nginx openssl \
                perl-net-telnet postgresql-client procps \
                tcpdump tcptraceroute wget \
    && rm -rf /var/cache/apk/* \
    && mkdir /certs /docker \
    && chmod 700 /certs \
    && openssl req \
       -x509 -newkey rsa:2048 -nodes -days 3650 \
       -keyout /certs/server.key -out /certs/server.crt -subj '/CN=localhost'

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) CH_ARCH="amd64" ;; \
        aarch64) CH_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    wget -O /usr/local/bin/clickhouse-client \
        "https://builds.clickhouse.com/master/${CH_ARCH}/clickhouse" && \
    chmod +x /usr/local/bin/clickhouse-client

RUN git clone https://github.com/ClickHouse/libc-blobs.git -b master --depth=1 && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
        aarch64) \
            [ -f /lib/ld-linux-aarch64.so.1 ] && \
                mv /lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1.bak 2>/dev/null || true; \
            cp -r libc-blobs/aarch64/lib/* /lib/ 2>/dev/null || true; \
            ;; \
        x86_64) \
            mkdir -p /lib64; \
            [ -f /lib64/ld-linux-x86-64.so.2 ] && \
                mv /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2.bak 2>/dev/null || true; \
            cp -r libc-blobs/x86_64/lib64/* /lib64/ 2>/dev/null || true; \
            cp -r libc-blobs/x86_64/lib/* /lib/ 2>/dev/null || true; \
            ;; \
    esac && \
    rm -rf libc-blobs

    # Copy a simple index.html to eliminate text (index.html) noise which comes with default nginx image.
# (I created an issue for this purpose here: https://github.com/nginxinc/docker-nginx/issues/234)

COPY index.html /usr/share/nginx/html/


# Copy a custom/simple nginx.conf which contains directives
#   to redirected access_log and error_log to stdout and stderr.
# Note: Don't use '/etc/nginx/conf.d/' directory for nginx virtual hosts anymore.
#   This 'include' will be moved to the root context in Alpine 3.14.

COPY nginx.conf /etc/nginx/nginx.conf

COPY entrypoint.sh /docker/entrypoint.sh

RUN chmod +x /docker/entrypoint.sh

# Start nginx in foreground:
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]



# Note: If you have not included the "bash" package, then it is "mandatory" to add "/bin/sh"
#         in the ENTNRYPOINT instruction.
#       Otherwise you will get strange errors when you try to run the container.
#       Such as:
#       standard_init_linux.go:219: exec user process caused: no such file or directory

# Run the startup script as ENTRYPOINT, which does few things and then starts nginx.
ENTRYPOINT ["/bin/sh", "/docker/entrypoint.sh"]





###################################################################################################

# Build and Push (to dockerhub) instructions:
# -------------------------------------------
# docker build -t local/network-multitool .
# docker tag local/network-multitool azolotareff/network-multitool
# docker login
# docker push azolotareff/network-multitool


# Pull (from dockerhub):
# ----------------------
# docker pull azolotareff/network-multitool


# Usage - on Docker:
# ------------------
# docker run --rm -it azolotareff/network-multitool /bin/bash
# OR
# docker run -d  azolotareff/network-multitool
# OR
# docker run -p 80:80 -p 443:443 -d  azolotareff/network-multitool
# OR
# docker run -e HTTP_PORT=1180 -e HTTPS_PORT=11443 -p 1180:1180 -p 11443:11443 -d  azolotareff/network-multitool


# Usage - on Kubernetes:
# ---------------------
# kubectl run multitool --image=azolotareff/network-multitool
