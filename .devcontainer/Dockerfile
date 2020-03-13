FROM quay.io/mhildenb/comparison-demo-base:1.0

# NOTE: If you need to run yum to install anything, you'll need to register the RHEL container using docker BUILDKIT to pass secrets
# If this is not supported by VSCode Remote, then you'll need to create a new base image outside of vscode / .devcontainer and make that image
# the base container to this one
USER root

# install stern
RUN cd /usr/local/bin && \
    wget https://github.com/wercker/stern/releases/download/1.6.0/stern_linux_amd64 && \
    mv stern_linux_amd64 stern && chmod 755 stern && \

# instal knative client
    wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/serverless/0.10.0/kn-linux-amd64-0.10.0.tar.gz | tar zxvf - -C /usr/local/bin && \
# instal hey
    wget https://storage.googleapis.com/hey-release/hey_linux_amd64 && \
    mv hey_linux_amd64 hey && chmod 755 hey && \
# install istioctl
    curl -L https://github.com/istio/istio/releases/download/1.4.0/istioctl-1.4.0-linux.tar.gz | tar -zxvf - -C /usr/local/bin && chmod 755 /usr/local/bin/istioctl

# install AWS cli
RUN curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm awscliv2.zip && rm -rf ./aws 
    # && ln -s /usr/local/bin/aws2 /usr/local/bin/aws

# install helm
RUN wget -qO- https://storage.googleapis.com/kubernetes-helm/helm-v2.12.2-linux-amd64.tar.gz | \
  tar -xzvf - && mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64


# clone the eb cli installation repo and run installer as root (doesn't work as local user and 
# though it isn't recommended to use sudo under docker build, it only installs correctly when 
# executing the command via sudo
# We run the installation command in two stages so that we can specify the installation directory
# see also: https://github.com/aws/aws-elastic-beanstalk-cli-setup#3-advanced-use
RUN cd /tmp && git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git && \
    sudo ./aws-elastic-beanstalk-cli-setup/scripts/python_installer 

ENV PATH="/root/.pyenv/versions/3.7.2/bin:$PATH"

RUN ln -s /root/.pyenv/versions/3.7.2/bin/virtualenv /usr/bin/ \
    && sudo echo "path is $PATH" && sudo python /tmp/aws-elastic-beanstalk-cli-setup/scripts/ebcli_installer.py --location /usr/local/lib/ebcli \
    && rm -rf /tmp/aws-elastic-beanstalk-cli-setup && rm /usr/bin/virtualenv

ENV PATH="/usr/local/lib/ebcli/.ebcli-virtual-env/executables:$PATH"

USER jboss

