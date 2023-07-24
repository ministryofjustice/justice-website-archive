FROM nginxinc/nginx-unprivileged

USER root

RUN apt-get update && apt-get -y install -qq libhttrack-dev httrack nodejs npm cron curl unzip htop procps

# Get AWS CLI V2
RUN set -eux; \
    \
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) arch='x86_64' ;; \
		armhf) arch='aarch64' ;; \
		arm64) arch='aarch64' ;; \
		*) arch='unimplemented' ; \
			echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding binary release."; echo >&2 ;; \
	esac; \
    \
    if [ "$arch" = 'unimplemented' ]; then \
        echo >&2; \
        echo >&2 'error: UNIMPLEMENTED'; \
        echo >&2 'TODO install awscli'; \
        echo >&2; \
        exit 1; \
    fi; \
    \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o "awscli.zip"; \
    unzip awscli.zip; \
    ./aws/install; \
    rm awscli.zip

## nginx user uid=101
COPY --chown=101:101 conf/node /usr/local/bin

ARG user=archiver
ARG uid=1001
RUN addgroup --gid ${uid} ${user} && \
    adduser --disabled-login --disabled-password --ingroup ${user} --home /${user} --gecos "${user} user" --shell /bin/bash --uid ${uid} ${user} && \
    usermod -a -G nginx ${user} && \
    usermod -a -G crontab ${user} && \
    mkdir /usr/lib/cron && \
    echo "${user}" > /usr/lib/cron/cron.allow && \
    echo "${user}" > /etc/cron.allow

COPY src/ /usr/share/nginx/html
COPY --chown=${user}:${user} conf/cron/tasks /etc/cron.d/archiver_schedule
COPY --chown=${user}:${user} conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=${user}:${user} conf/entrypoint/ /docker-entrypoint.d
COPY --chown=${user}:${user} conf/s3-sync.sh /usr/bin/s3sync

## -> make init scripts executable
RUN chown -R ${user}:${user} /usr/share/nginx/html && \
    chmod -R +x /docker-entrypoint.d/ && \
    chmod +x /usr/bin/s3sync

## -> set up user to access the cron
RUN chgrp crontab /usr/bin/crontab && \
    chgrp crontab /usr/sbin/cron && \
    chgrp crontab /var/spool/cron && \
    chgrp crontab /var/run && \
    chmod 4774 -R /var/spool/cron && \
    chmod gu+rw /var/run && \
    chmod gu+s /usr/sbin/cron && \
    chmod -R g+s /var/spool/cron && \
    crontab -u ${user} /etc/cron.d/archiver_schedule && \
    # logging
    touch /${user}/cron.log && \
    chmod 666 /${user}/cron.log && \
    chown ${user}:${user} /${user}/cron.log

RUN apt remove -y unzip

## let's be our worker user
USER ${uid}
