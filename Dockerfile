# syntax = docker/dockerfile:1.0-experimental

#
# This is the base dockerfile to be used with the BUILDKIT to build the 
# image that the .devcontainer docker image is based on
# 
FROM quay.io/mhildenb/cloudnative-workspaces-quarkus:1.0

USER root

# command line for this would look something like
# docker build --progress=plain --secret id=myuser,src=docker-secrets/myuser.txt --secret id=mypass,src=docker-secrets/mypass.txt -t quay.io/mhildenb/comparison-demo-base:1.0 .
RUN --mount=type=secret,id=myuser --mount=type=secret,id=mypass \
    subscription-manager register --username=$(cat /run/secrets/myuser) \
    --password=$(cat /run/secrets/mypass) --auto-attach

# prerequisites for the eb command line
RUN yum group install -y "Development Tools" && \
     yum install -y zlib-devel openssl-devel ncurses-devel libffi-devel sqlite-devel.x86_64 readline-devel.x86_64 \
     bzip2-devel.x86_64

RUN subscription-manager unregister

# necessary for the way the installer works that it goes to root's home directory (otherwise this is jboss home)
ENV HOME=/root
USER root

# clone the eb cli installation repo and run installer as root (doesn't work as local user)
# do this in two stages so that we can specify the installation directory
RUN cd /tmp && git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git && \
    sudo ./aws-elastic-beanstalk-cli-setup/scripts/python_installer \
    && echo 'export PATH="/root/.pyenv/versions/3.7.2/bin:$PATH"' >> /root/.bash_profile && source /root/.bash_profile

ENV PATH="/root/.pyenv/versions/3.7.2/bin:$PATH"
RUN ln -s /root/.pyenv/versions/3.7.2/bin/virtualenv /usr/bin/

RUN sudo echo "path is $PATH" && sudo python /tmp/aws-elastic-beanstalk-cli-setup/scripts/ebcli_installer.py --location /usr/local/lib/ebcli \
    && echo 'export PATH="/usr/local/lib/ebcli/.ebcli-virtual-env/executables:$PATH"' >> ~/.bash_profile && source ~/.bash_profile \
    && rm -rf /tmp/aws-elastic-beanstalk-cli-setup/

USER jboss

# reset the home directory
ENV HOME=/home/jboss

# put the cli in our path
RUN echo 'export PATH="/usr/local/lib/ebcli/.ebcli-virtual-env/executables:$PATH"' >> ~/.zshenv && source ~/.zshenv

