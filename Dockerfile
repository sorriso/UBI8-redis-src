# docker pull registry.access.redhat.com/ubi8/ubi-minimal:8.5-218

FROM registry.access.redhat.com/ubi8/ubi-minimal:8.5-218

###########################################################
#
# LABEL Mandatory for the Pipeline - DO NOT DELETE
#
###########################################################

LABEL name=redis_community \
      authors=sorriso \
      version=v0.01

###########################################################
#
# ENV Mandatory for the Pipeline - DO NOT DELETE
#
###########################################################

USER 0

###########################################################
#
# Custom ENV configuration
#
###########################################################

ENV REDIS_VERSION=6.2.6 \
    REDIS_PASSWORD=defaultRedisPasswordToBeSetUpWithinEnv \
    GOSU_VERSION=1.14 \
    GNUPGHOME='' \
    GITHUB_RELEASE_URL=https://github.com/

###########################################################
#
# System update with Standard & custom REPO
#
###########################################################

COPY /repo/ubi.repo  /etc/yum.repos.d/ubi.repo
COPY /repo/centos-8.repo /etc/yum.repos.d/centos-8.repo
COPY /gpg /etc/pki/rpm-gpg
COPY /iron-scripts/ /iron-scripts/
COPY /config/redis.conf /config/redis.conf
COPY /cert/ /cert/
COPY /scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN set -eux \

    &&  microdnf repolist --disableplugin=subscription-manager \
    &&  microdnf upgrade --disableplugin=subscription-manager -y \

###########################################################
#
# Prerequisites installation
#
###########################################################

    &&  microdnf install -y --disableplugin=subscription-manager \
        dirmngr \
        gnupg \
        dpkg-dev \
        gcc \
        glibc-devel \
        openssl-devel \
        make \
        tar \
        gzip \
        findutils \
        procps-ng \
        shadow-utils \
        dpkg \

###########################################################
#
# Application installation
#
###########################################################

    && curl -L ${GITHUB_RELEASE_URL}/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 -o /sbin/gosu \
    && curl -L ${GITHUB_RELEASE_URL}/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc -o /sbin/gosu.asc \
    && chmod +x /sbin/gosu \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /sbin/gosu.asc /sbin/gosu \
    && command -v gpgconf && gpgconf --kill all || : \
    && rm -rf "$GNUPGHOME" /sbin/gosu.asc \
    && gosu --version \
    && gosu nobody true \

    && curl -L ${GITHUB_RELEASE_URL}/redis/redis/archive/refs/tags/${REDIS_VERSION}.tar.gz -o /redis.tar.gz \
    && curl -L https://raw.githubusercontent.com/redis/redis-hashes/master/README -o /redishashlist.txt \
    && redishashline=$(grep -n "hash redis-${REDIS_VERSION}.tar.gz" /redishashlist.txt) \

    && echo $redishashline \

    && read -r ONE TWO THREE FOUR FIVE <<< "${redishashline}" \

    && echo $FOUR \

    && sha256sum /redis.tar.gz > /checksum.txt \
    && checksum=$(cat /checksum.txt) \
    && read -r AA BB <<< "${checksum}" \

    && mkdir -p /usr/src/redis \
    && tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
    && rm /redis.tar.gz \
    && rm /redishashlist.txt \

    && echo $AA \

    # && if [[ "${FOUR}" != "${AA}" ]] ; then echo "checksum failed" ; exit 1 ; fi \

    && grep -E '^ *createBoolConfig[(]"protected-mode",.*, *1 *,.*[)],$' /usr/src/redis/src/config.c \
    && sed -ri 's!^( *createBoolConfig[(]"protected-mode",.*, *)1( *,.*[)],)$!\10\2!' /usr/src/redis/src/config.c \
    && grep -E '^ *createBoolConfig[(]"protected-mode",.*, *0 *,.*[)],$' /usr/src/redis/src/config.c \

    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && extraJemallocConfigureFlags="--build=$gnuArch" \
    && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
    		amd64 | i386 | x32) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=12" ;; \
    		*) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=16" ;; \
    	esac \
	&& extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-hugepage=21" \
	&& grep -F 'cd jemalloc && ./configure ' /usr/src/redis/deps/Makefile \
	&& sed -ri 's!cd jemalloc && ./configure !&'"$extraJemallocConfigureFlags"' !' /usr/src/redis/deps/Makefile \
	&& grep -F "cd jemalloc && ./configure $extraJemallocConfigureFlags " /usr/src/redis/deps/Makefile \
	&& export BUILD_TLS=yes \
	&& make -C /usr/src/redis -j "$(nproc)" all \
	&& make -C /usr/src/redis install \

    && serverMd5="$(md5sum /usr/local/bin/redis-server | cut -d' ' -f1)"; export serverMd5 \
    && find /usr/local/bin/redis* -maxdepth 0 \
    	-type f -not -name redis-server \
    	-exec sh -eux -c ' \
    		md5="$(md5sum "$1" | cut -d" " -f1)"; \
    		test "$md5" = "$serverMd5"; \
    	' -- '{}' ';' \
    	-exec ln -svfT 'redis-server' '{}' ';' \
    && rm -r /usr/src/redis \

	&& redis-cli --version \
	&& redis-server --version \

  && mkdir -p /var/log/ \
  && ln -sf /dev/stdout /var/log/redis.log \

###########################################################
#
# create user / usergroup
#
###########################################################

    && mkdir /data \
    && groupadd -r redis \
    && useradd -r -g redis redis \
    && chown redis:redis /data \
    && usermod -a -G root redis \

###########################################################
#
# hardening
#
###########################################################

# to be done

###########################################################
#
# cleanup / remove pkg
#
###########################################################

  &&  microdnf remove -y --disableplugin=subscription-manager \
      dirmngr \
      gnupg \
      gzip \
      procps-ng \
      shadow-utils \
      dpkg-perl \
      dpkg-dev \
      dpkg \
      gcc \
      make \
      openssl-devel \
      libxcrypt-devel \
      glibc-devel \
      tar \
  &&  microdnf clean all --disableplugin=subscription-manager \
  && rm -rf /iron-scripts/

###########################################################
#
# Docker image configuration
#
###########################################################

USER redis

VOLUME /data

WORKDIR /data

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 6379 6380

CMD ["redis-server", "/config/redis.conf", "--requirepass", "$REDIS_PASSWORD"]
