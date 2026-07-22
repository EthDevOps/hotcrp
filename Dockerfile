# HotCRP container image.
#
# Runs HotCRP under Apache + mod_php, which works out of the box with the
# rewrite rules shipped in `.htaccess`. Configuration is supplied at runtime
# through environment variables (see docker/options.php and docker-compose.yml).

FROM php:8.4-apache

# System packages:
#  - poppler-utils: `pdftohtml`/`pdftoppm`, used by the paper-format checker (banal)
#  - default-mysql-client: used by the entrypoint to load the schema on first boot
#  - msmtp / msmtp-mta: HotCRP mails through a local sendmail binary (it has no
#    native SMTP); msmtp-mta provides /usr/sbin/sendmail that relays via SMTP
#  - the -dev libraries back the PHP extensions installed just below
RUN apt-get update && apt-get install -y --no-install-recommends \
        poppler-utils \
        default-mysql-client \
        msmtp \
        msmtp-mta \
        libicu-dev \
        libonig-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        mysqli \
        intl \
        mbstring \
        zip \
        gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# HotCRP's `.htaccess` needs mod_rewrite, and the site is served over the proxy
# headers when behind a load balancer.
RUN a2enmod rewrite remoteip

# PHP runtime tuning. Mirrors the recommendations in README.md / .user.ini so
# large paper uploads work and sessions live long enough.
# Proxy-header normalization runs before every request (see trusted-proxy.php).
COPY docker/trusted-proxy.php /usr/local/lib/hotcrp/trusted-proxy.php
RUN { \
        echo 'upload_max_filesize = 30M'; \
        echo 'post_max_size = 35M'; \
        echo 'max_input_vars = 4096'; \
        echo 'memory_limit = 256M'; \
        echo 'session.gc_maxlifetime = 86400'; \
        echo 'auto_prepend_file = /usr/local/lib/hotcrp/trusted-proxy.php'; \
    } > /usr/local/etc/php/conf.d/hotcrp.ini

# Point Apache at the repo root and allow the shipped `.htaccess` to take effect.
ENV APACHE_DOCUMENT_ROOT=/var/www/html
RUN sed -ri 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf

WORKDIR /var/www/html

# Copy the application. `.dockerignore` keeps local state (conf/, logs, docs,
# vendor, node_modules, VCS metadata) out of the image.
COPY . /var/www/html

# The env-driven configuration file and the first-boot entrypoint.
COPY docker/options.php /var/www/html/conf/options.php
COPY docker/entrypoint.sh /usr/local/bin/hotcrp-entrypoint

# Writable directories for the document store, logs, and sessions.
RUN mkdir -p /var/www/html/conf /var/www/html/docs /var/www/html/logs \
    && chmod +x /usr/local/bin/hotcrp-entrypoint \
    && chown -R www-data:www-data /var/www/html/conf /var/www/html/docs /var/www/html/logs

EXPOSE 80

ENTRYPOINT ["hotcrp-entrypoint"]
CMD ["apache2-foreground"]
