FROM wordpress:5.6.0

ARG APCU_VERSION=5.1.19

RUN apt-get update \
 && apt-get install -y unzip python2.7 default-mysql-client jq \
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/python2.7 /usr/bin/python \
 && curl https://storage.googleapis.com/pub/gsutil.tar.gz | tar -xzf - -C /usr/local \
 && ln -s /usr/local/gsutil/gsutil /usr/local/bin/gsutil \
 && pecl install apcu-${APCU_VERSION} \
 && docker-php-ext-enable apcu

ADD *.sh /wordpress/
ADD install-*.php /wordpress/
ENTRYPOINT [ "/wordpress/entrypoint.sh" ]

#RUN echo "extension=apcu.so" >> /usr/local/etc/php/php.ini && \
#    echo "apc.enable_cli=1" >> /usr/local/etc/php/php.ini && \
#    echo "apc.enable=1" >> /usr/local/etc/php/php.ini
