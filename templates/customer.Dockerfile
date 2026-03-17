FROM ubuntu:24.04

# 1. Install Runtimes & Process Supervisor
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    nginx php8.4-fpm php8.4-mysql php8.4-xml php8.4-curl \
    mariadb-client cron curl git unzip supervisor && \
    rm -rf /var/lib/apt/lists/*

# 2. Setup the Restricted User
RUN useradd -m -s /bin/bash customer

# 3. Secure Nginx & PHP
COPY nginx-provider.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN sed -i 's/user = www-data/user = customer/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/group = www-data/group = customer/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/listen.owner = www-data/listen.owner = customer/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/listen.group = www-data/listen.group = customer/' /etc/php/8.4/fpm/pool.d/www.conf && \
    mkdir -p /var/run/php /var/log/supervisor

WORKDIR /var/www/html

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
