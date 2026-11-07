FROM debian:12.12-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server python3 \
    && rm -rf /var/lib/apt/lists/* /etc/ssh/ssh_host_* \
    && printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d \
    && printf 'PasswordAuthentication no\nPermitRootLogin prohibit-password\n' > /etc/ssh/sshd_config.d/lab.conf
COPY docker/target.sh /usr/local/bin/target.sh
RUN chmod +x /usr/local/bin/target.sh
ENTRYPOINT ["/usr/local/bin/target.sh"]
