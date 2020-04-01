# docker_mdns

Automatic docker mdns announcer designed to work with traefik.

## Installation

- `shards build`
- `cp bin/docker_mdns /usr/local/bin`
- `cp docker-mdns@.service /etc/systemd/system`
- `systemctl daemon-reload`
- `systemctl enable docker-mdns@{your_interface}`
- `systemctl start docker-mdns@{your_interface}`

## Usage

Label your local containers with:

```
traefik.http.routers.<service_name>.rule = Host(`chosen_hostname.local`)
traefik.http.services.<service_name>.loadbalancer.server.port = <port>
```

## Development

Warning: This is a home solution / shit code.

## Contributing

1. Fork it (<https://gitlab.com/viraptor/docker_mdns/-/forks/new>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stanisław Pitucha](https://gitlab.com/viraptor) - creator and maintainer
