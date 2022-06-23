FROM centos:7

COPY alinux-plus.repo /etc/yum.repos.d/
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ARG DRAGONWELL_JDK_URL=https://github.com/alibaba/dragonwell11/releases/download/dragonwell-11.0.15.11.9_jdk-11.0.15-ga/Alibaba_Dragonwell_11.0.15.11.9_x64_linux.tar.gz

# Install essential utils
RUN yum update -y && \
    yum install sudo hostname telnet net-tools vim tree less file tcpdump wget mysql tzdata openssl curl ca-certificates fontconfig gzip tar tsar dstat mpstat iostat cronie -y && \
    sed -i '/session required pam_loginuid.so/d' /etc/pam.d/crond && \
    yum clean all && rm -rf /var/cache/yum && rm -rf /var/tmp/yum-*

# Create user "admin" and add it into sudo group
RUN useradd -ms /bin/bash admin && \
    echo "admin:admin" | chpasswd && \
    echo "admin    ALL=(ALL)    NOPASSWD: ALL" >> /etc/sudoers

RUN set -eux; \
    curl -Lf#So /tmp/openjdk.tar.gz ${DRAGONWELL_JDK_URL}; \
    mkdir -p /opt/java/dragonwell; \
    cd /opt/java/dragonwell; \
    tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
    rm -fr man/ja_JP.UTF-8 demo; \
    rm -rf /tmp/openjdk.tar.gz;

RUN \
    echo "root hard nofile 65535" >> /etc/security/limits.conf && \
    echo "root soft nofile 65535" >> /etc/security/limits.conf && \
    echo "admin soft nofile 65535" >> /etc/security/limits.conf && \
    echo "admin hard nofile 65535" >> /etc/security/limits.conf && \
    echo "admin soft nproc 65535" >> /etc/security/limits.conf && \
    echo "admin hard nproc 65535" >> /etc/security/limits.conf && \
    echo "export TERM=xterm" >> /etc/profile && \
    echo "export LANG='en_US.UTF-8'" >> /etc/profile && \
    echo "export JAVA_HOME=/opt/java/dragonwell" >> /etc/profile && \
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile && \
    echo "export TERM=xterm" >> /home/admin/.bashrc && \
    echo "export LANG='en_US.UTF-8'" >> /home/admin/.bashrc && \
    echo "export JAVA_HOME=/opt/java/dragonwell" >> /home/admin/.bashrc && \
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /home/admin/.bashrc && \
    echo "set ic hls is hid nu" >> /etc/vimrc && \
    true

RUN \ 
    mkdir -p /home/admin/tools/ && \
    curl -Lf#So /home/admin/tools/arthas-boot.jar https://arthas.aliyun.com/arthas-boot.jar && \
    curl -Lf#So /home/admin/tools/async-profiler-2.7-linux-x64.tar.gz "https://github.com/jvm-profiling-tools/async-profiler/releases/download/v2.7/async-profiler-2.7-linux-x64.tar.gz" && \
    chown admin:admin -R /home/admin/tools && \
    true

# Remove localtime to make mount possible.
RUN rm -f /etc/localtime