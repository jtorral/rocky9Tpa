FROM rockylinux:9.3 AS base

# install base utils and official docker cli 

RUN dnf -y --setopt=sslverify=false update && \
    dnf install -y --setopt=sslverify=false dnf-plugins-core && \
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y --setopt=sslverify=false \
        wget telnet jq vim sudo gnupg openssh-server openssh-clients \
        procps-ng net-tools iproute iputils less diffutils watchdog epel-release \
        docker-ce-cli git make emacs-nox python3-pip file && \
    dnf clean all && rm -rf /var/cache/dnf

# install python docker sdk needed for tpa/ansible

RUN pip3 install --no-cache-dir docker

# install edb repository tpa and prep for a tpa admiN
# We pass our token as argument at build time

ARG EDBTOKEN=""
ENV EDBTOKEN=${EDBTOKEN}

ARG ADMINUSER="tpa_admin"
ENV ADMINUSER=${ADMINUSER}

# saving here for reference. easy to overlook. double quotes vs single quotes based on using arg or not.
# RUN curl -1sSLf 'https://downloads.enterprisedb.com/*********/enterprise/setup.rpm.sh' | sudo -E bash && \

RUN curl -1sSLf -k "https://downloads.enterprisedb.com/${EDBTOKEN}/enterprise/setup.rpm.sh"  | sudo -E bash && \
    dnf install -y --setopt=sslverify=false tpaexec && \
    dnf clean all && rm -rf /var/cache/dnf

# crb / libmemcached setup 

RUN dnf config-manager --set-enabled crb && \
    dnf install -y --setopt=sslverify=false libmemcached-awesome && \
    dnf clean all && rm -rf /var/cache/dnf

# final config and entrypoint

COPY id_rsa /
COPY id_rsa.pub /
COPY authorized_keys /

# set up ssh directory for the root user to avoid permission issues during TPA runs
# using the pre-generated ssh files included in this repo

RUN mkdir -p /root/.ssh && \
    cp /id_rsa /root/.ssh/id_rsa && \
    cp /id_rsa.pub /root/.ssh/id_rsa.pub && \
    cp /authorized_keys /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/id_rsa

EXPOSE 22  

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
