# CEPH BASE IMAGE
# CEPH VERSION: Firefly
# CEPH VERSION DETAIL: 0.80.8

FROM ubuntu:14.04
MAINTAINER Sébastien Han "seb@redhat.com"

ENV CEPH_VERSION hammer
ENV CONSULORETCD_VERSION v0.3

ENV CONFD_VERSION 0.7.1
ENV CONFD_ARCH linux-amd64

ENV ETCDCTL_VERSION v2.0.10
ENV ETCDCTL_ARCH linux-amd64

# Install prerequisites
RUN apt-get update
RUN apt-get install -y wget
RUN apt-get install -y unzip


# Install Ceph
RUN wget -q -O- 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | apt-key add -
RUN echo deb http://ceph.com/debian-$CEPH_VERSION/ trusty main | tee /etc/apt/sources.list.d/ceph-$CEPH_VERSION.list
RUN apt-get update
RUN apt-get install -y --force-yes ceph


#install consuloretcd-kv
RUN wget -q -O- "http://github.com/AcalephStorage/consuloretcd-kv/releases/download/v0.2/consuloretcd-kv-v0.3.tar" | tar xvf - -C/tmp/ consuloretcd-kv
RUN mv /tmp/consuloretcd-kv /usr/local/bin/consuloretcd


# Install confd
ADD https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-${CONFD_ARCH} /usr/local/bin/confd
RUN chmod +x /usr/local/bin/confd
RUN mkdir -p /etc/confd/conf.d
RUN mkdir -p /etc/confd/templates

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
