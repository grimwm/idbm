FROM docker.io/fedora:35

WORKDIR /app

RUN dnf upgrade -y
RUN dnf install -y awscli inotify-tools
RUN dnf clean all

COPY sync.sh /app
RUN chmod +x /app/sync.sh

CMD ["/app/sync.sh"]
