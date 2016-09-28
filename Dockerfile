# A CentOS7 Stack image using upstream repo
FROM fedora:24
MAINTAINER Brian C. Lane <bcl@redhat.com>
RUN dnf -y install dnf-plugins-core && dnf -y copr enable @modularity/modulemd && dnf -y install lorax anaconda-tui python3-bottle python3-modulemd

COPY . /root/lmc-composer-demo/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
