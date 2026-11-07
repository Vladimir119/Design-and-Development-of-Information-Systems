FROM python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir ansible-core==2.19.3
WORKDIR /ansible
COPY . .
RUN tar --mode=0755 --owner=0 --group=0 -czf /opt/app.tar.gz -C app . && chmod +x docker/master.sh
ENV ANSIBLE_CONFIG=/ansible/ansible.cfg
ENTRYPOINT ["/ansible/docker/master.sh"]
