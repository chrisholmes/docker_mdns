FROM ruby:2.7.1 

RUN mkdir /app
COPY . /app
WORKDIR /app
RUN bundle
RUN ls /app
VOLUME /var/run/dbus

ENTRYPOINT ["/app/bin/docker_mdns"]
CMD ["eth0"]
