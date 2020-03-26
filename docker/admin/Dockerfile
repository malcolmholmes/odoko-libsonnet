FROM ubuntu:18.04

RUN apt-get update \
 && apt-get install -y \
       curl \
       python \
       cron \
       dnsutils \
       gnupg \
       lsb-release \
       jq \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - \
 && curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)"-pgdg main | tee /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y google-cloud-sdk \
 && apt-get clean \
 && rm -rf  /tmp/* /var/tmp/* /var/lib/apt/lists/*

WORKDIR /admin
ADD entrypoint.sh /admin
ADD scripts/ /admin/scripts/

ENTRYPOINT ["/admin/entrypoint.sh"]
