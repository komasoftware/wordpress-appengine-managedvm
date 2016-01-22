FROM php:5.6-apache

# ENV WORDPRESS_DB_HOST="your-ip-address:3306"
ENV WORDPRESS_DB_HOST="localhost:/cloudsql/<your-project-id>:<your-region>:<your-cloudsql-instance-name>"
ENV WORDPRESS_DB_USER="wordpress"
ENV WORDPRESS_DB_PASSWORD="yourpassword"
ENV WORDPRESS_DB_NAME="wordpress"
ENV WORDPRESS_DEBUG="true"

# enable required Apache module
RUN a2enmod rewrite expires

# install the PHP extensions we need
RUN apt-get update && apt-get install -y libpng12-dev libjpeg-dev unzip && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd mysqli opcache

ENV WORDPRESS_VERSION 4.4.1
ENV WORDPRESS_SHA1 89bcc67a33aecb691e879c818d7e2299701f30e7

# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o wordpress.tar.gz -SL https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz \
	&& echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
	&& tar -xzf wordpress.tar.gz -C /usr/src/ \
	&& rm wordpress.tar.gz \
	&& curl -o google-app-engine.latest-stable.zip -SL https://downloads.wordpress.org/plugin/google-app-engine.latest-stable.zip \
	&& unzip -q -d /usr/src/wordpress/wp-content/plugins google-app-engine.latest-stable.zip \
	&& chown -R www-data:www-data /usr/src/wordpress

# install PHP GAE SDK
RUN curl -o /tmp/google_appengine_1.9.31.zip -SL https://storage.googleapis.com/appengine-sdks/featured/google_appengine_1.9.31.zip \
 && unzip -q -d /tmp /tmp/google_appengine_1.9.31.zip \
 && cp -r /tmp/google_appengine/php/sdk/* /usr/local/lib/php/ \
 && rm -f /tmp/google_appengine_1.9.31.zip \
 && rm -rf /tmp/google_appengine

# copy updated apache configuration
# Listen to port 8080 instead of 80
COPY docker-apache2.conf /etc/apache2/apache2.conf

# startup and health check responses
RUN mkdir -p /var/www/html/_ah
RUN echo "OK" > /var/www/html/_ah/start
RUN echo "<?php phpinfo(); ?>" > /var/www/html/_ah/health

# make the apache log files automagically integrate with Cloud Logging
RUN if [ ! -d "/var/log/app_engine/custom_logs" ]; then \
	mkdir -p /var/log/app_engine/custom_logs/ \
	&& chmod a+rw /var/log/app_engine/custom_logs; \
fi

# copy entry point to the container
COPY docker-entrypoint.sh /entrypoint.sh

# start the container
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
