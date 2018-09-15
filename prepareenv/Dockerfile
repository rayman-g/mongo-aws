FROM centos:centos7
COPY files/mongodb-org-3.4.repo /etc/yum.repos.d/mongodb-org-3.4.repo
RUN yum -y update; yum clean all
RUN yum install mongodb-org -y; yum clean all
EXPOSE 27017
