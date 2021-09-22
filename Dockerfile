FROM       ubuntu:xenial

RUN        apt-get update -yqq \
           && apt-get install -yqq --no-install-recommends \
               ca-certificates \
               build-essential \
               curl \
           && rm -rf /var/lib/apt/lists/*

#RUN        curl -fsSL https://github.com/luvit/lit/raw/master/get-lit.sh | sh
#RUN        mv luvit /usr/bin && mv luvi /usr/bin && mv lit /usr/bin

WORKDIR    /var/www/html

#COPY       docker-entrypoint.sh /
#ENTRYPOINT ["/docker-entrypoint.sh"]

ADD         ./swampy swampy-server

CMD         cd swampy-server; pwd; ./luvit app/httpsserver.lua
