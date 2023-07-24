FROM nginxinc/nginx-unprivileged

USER root

RUN apt-get update && apt-get -y install -qq libhttrack-dev httrack nodejs npm curl unzip htop procps

# Get AWS CLI V2
RUN set -eux; \
    \
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) arch='x86_64' ; supercronic='supercronic-linux-amd64' ; supercronic_sha='7a79496cf8ad899b99a719355d4db27422396735' ;; \
		armhf) arch='aarch64' ; supercronic='supercronic-linux-arm64' ; supercronic_sha='e4801adb518ffedfd930ab3a82db042cb78a0a41' ;; \
		arm64) arch='aarch64' ; supercronic='supercronic-linux-arm64' ; supercronic_sha='e4801adb518ffedfd930ab3a82db042cb78a0a41' ;; \
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
    rm awscli.zip; \
    \
    ## -> alternative cron
    curl -fsSLO "https://github.com/aptible/supercronic/releases/download/v0.2.26/${supercronic}" && \
    echo "${supercronic_sha}  ${supercronic}" | sha1sum -c - && \
    chmod +x "${supercronic}" && \
    mv "${supercronic}" "/usr/local/bin/${supercronic}" && \
    ln -s "/usr/local/bin/${supercronic}" /usr/local/bin/supercronic

## nginx user uid=101
COPY --chown=101:101 conf/node /usr/local/bin

ARG user=archiver
ARG uid=1001
RUN addgroup --gid ${uid} ${user} && \
    adduser --disabled-login --disabled-password --ingroup ${user} --home /${user} --gecos "${user} user" --shell /bin/bash --uid ${uid} ${user} && \
    usermod -a -G nginx ${user}

COPY --chown=${user}:${user} src/ /usr/share/nginx/html
COPY --chown=${user}:${user} conf/cron/ /etc/cron.d/
COPY --chown=${user}:${user} conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=${user}:${user} conf/entrypoint/ /docker-entrypoint.d
COPY --chown=${user}:${user} conf/s3-sync.sh /usr/bin/s3sync
COPY --chown=${user}:${user} conf/start-cron-sync.sh /usr/bin/s3sync-cron

## -> make init scripts executable
RUN chown -R ${user}:${user} /usr/share/nginx/html && \
    chmod -R +x /docker-entrypoint.d/ && \
    chmod +x /usr/bin/s3sync && \
    chmod +x /usr/bin/s3sync-cron && \
    chown ${user}:${user} /etc/cron.d/process-mirror /etc/cron.d/process-sync && \
    # logging
    touch /${user}/s3sync.log && \
    touch /${user}/supercronic_sync.log && \
    touch /${user}/supercronic_mirror.log && \
    chown ${user}:${user} /${user}/s3sync.log && \
    chown ${user}:${user} /${user}/supercronic_sync.log && \
    chown ${user}:${user} /${user}/supercronic_mirror.log

RUN apt remove -y unzip

## let's be our worker user
USER ${uid}
