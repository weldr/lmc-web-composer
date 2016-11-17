# A CentOS7 Stack image using upstream repo
FROM fedora:24
MAINTAINER Brian C. Lane <bcl@redhat.com>
RUN dnf -y install dnf-plugins-core && dnf -y copr enable @modularity/modulemd && dnf -y install lorax anaconda-tui python3-bottle python3-modulemd gnupg tar git && dnf -y install make python3-pylint python3-pocketlint python3-sphinx_rtd_theme python3-magic

# Based on official node docker image
# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 6.7.0

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

RUN echo 'PATH=/usr/local/bin/:$PATH' >> /etc/bashrc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EXPOSE 80

## Do the things more likely to change below here. ##

# Update node dependencies only if they have changed
COPY ./share/composer-UI/package.json /root/lmc-composer-demo/share/composer-UI/package.json
RUN cd /root/lmc-composer-demo/share/composer-UI/ && npm install

# Copy the rest of the UI files over and compile them
COPY ./share/composer-UI/ /root/lmc-composer-demo/share/composer-UI/
RUN cd /root/lmc-composer-demo/share/composer-UI/ && node run build

# Copy over everything else
# Do not re-copy ./share/composer-UI/
COPY ./share/composer-template.ks /root/lmc-composer-demo/share/
COPY ./share/html/ /root/lmc-composer-demo/share/html/
COPY ./share/recipes/ /root/lmc-composer-demo/share/recipes/
COPY ./share/templates.d/ /root/lmc-composer-demo/share/templates.d/
COPY ./src/ /root/lmc-composer-demo/src/
COPY ./Makefile /root/lmc-composer-demo/
COPY ./tests /root/lmc-composer-demo/tests/
