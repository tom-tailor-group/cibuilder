FROM alpine:latest as base
RUN apk update
RUN apk add curl unzip
WORKDIR /tmp

## Terraform
FROM base as terraform
ARG version="0.13.5"
ARG checksum="f7b7a7b1bfbf5d78151cfe3d1d463140b5fd6a354e71a7de2b5644e652ca5147"
RUN curl -sSL -o terraform.zip \
    https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip
RUN unzip terraform.zip
RUN echo Download checksum: $(sha256sum terraform.zip)
RUN echo "${checksum}  terraform.zip" | sha256sum -c

## Kubectl
FROM base as kubectl
ARG k8s_version="1.18.15"
ARG k8s_checksum="eb5a5dd0a72795942ab81d1e4331625e80a90002c8bb39b2cb15aa707a3812c6"
RUN curl -LO \
    https://dl.k8s.io/release/v${k8s_version}/bin/linux/amd64/kubectl
RUN echo Download checksum: $(sha256sum kubectl)
RUN echo "${k8s_checksum}  kubectl" | sha256sum -c
RUN chmod +x kubectl

## Terragrunt
FROM base as terragrunt
ARG tg_version="0.25.5"
ARG tg_checksum="a7699227a5d8b02f9facaeea9919261e727ac2dec2f81fee6455a52d06df4648"
RUN curl -sSL -o terragrunt \
    https://github.com/gruntwork-io/terragrunt/releases/download/v${tg_version}/terragrunt_linux_amd64
RUN echo Download checksum: $(sha256sum terragrunt)
RUN echo "${tg_checksum}  terragrunt" | sha256sum -c
RUN chmod +x terragrunt

## Helm3
FROM base as helm3
ARG helm3_version="3.3.3"
ARG checksum="246d58b6b353e63ae8627415a7340089015e3eb542ff7b5ce124b0b1409369cc"
RUN curl -sSL -o helm3.tgz \
    https://get.helm.sh/helm-v${helm3_version}-linux-amd64.tar.gz
RUN echo Download checksum: $(sha256sum helm3.tgz)
RUN tar zxf helm3.tgz
RUN chmod +x linux-amd64/helm

## jq (to convert strings into JSON)
FROM base as jq
RUN curl -sSL -o jq \
    https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
RUN chmod +x jq

## Main Image
FROM amazonlinux:2
#LABEL maintainer example@example.com

COPY --from=terraform   /tmp/terraform    /usr/local/bin/terraform
COPY --from=terragrunt  /tmp/terragrunt   /usr/local/bin/terragrunt
COPY --from=kubectl     /tmp/kubectl      /usr/local/bin/kubectl
COPY --from=helm3       /tmp/linux-amd64/helm         /usr/local/bin/helm3
COPY --from=jq          /tmp/jq           /usr/local/bin/jq

ARG ENVIRONMENT
ARG STAGE

RUN yum install -y python2-pip python2-boto3 python2-botocore awscli shadow-utils openssh-clients expect git tar && yum clean all
RUN pip install ansible
RUN useradd -m -d /home/jenkins -u 1000 jenkins

RUN mkdir /tmp/provision
WORKDIR /tmp/provision

ARG HELM3_PLUGIN_DIFF_VERSION="v3.1.3"
USER jenkins

RUN helm repo add stable https://charts.helm.sh/stable/
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM3_PLUGIN_DIFF_VERSION}
RUN mkdir -p /home/jenkins/.terraform.d/plugins/
