from centos:7 as build

WORKDIR /home/admin

COPY polardb-x-0.5.0-1.el7.centos.x86_64.rpm /home/admin/

RUN rpm -ivh polardb-x-0.5.0-1.el7.centos.x86_64.rpm --nodeps &&    \
    rm polardb-x-0.5.0-1.el7.centos.x86_64.rpm

from centos:7

# Install essential utils
RUN yum install sudo hostname telnet net-tools vim tree less file java-1.8.0-openjdk-devel -y && \
    yum install openssl-devel ncurses-devel libaio-devel -y   &&  \
    yum clean all && rm -rf /var/cache/yum && rm -rf /var/tmp/yum-*

# Create user "admin" and add it into sudo group
RUN useradd -ms /bin/bash admin && \
    echo "admin:admin" | chpasswd && \
    echo "admin    ALL=(ALL)    NOPASSWD: ALL" >> /etc/sudoers &&   \
    echo 'PATH="/home/admin/polardb-x/galaxyengine/u01/mysql/bin:$PATH"' >> /home/admin/.bashrc && \
    echo "export PATH" >> /home/admin/.bashrc


WORKDIR /home/admin

COPY --from=build --chown=admin /home/admin/polardb-x polardb-x

# Copy entrypoint.sh
COPY --chown=admin entrypoint.sh entrypoint.sh

USER admin

# Set command to entrypoint.sh
ENTRYPOINT /home/admin/entrypoint.sh