# Copyright 2020 Christopher Holmes
# Copyright 2020 Stanisław Pitucha
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require "dbus"

module DockerMdns
  Location = Struct.new(:name)

  class Announcer
    BUS = DBus.system_bus
    # PUBLISHED = {} of String => DBus::Object


    def initialize(interface)
      @address = find_interface_address(interface)
      @interface = resolve_avahi_interface(interface)
      @published = {}
    end

    def process(event)
      if event.action == "start"
        get_location(event.actor.attributes).each do |router, location|
          publish(router, location)
        end
      elsif event.action == "die"
        get_location(event.actor.attributes).each do |router, location|
          unpublish(router, location)
        end
      end
    end

    def process_existing(containers)
      containers.each do |container|
        get_location(container.info['Labels']).each do |router, location|
          publish(router, location)
        end
      end
    end

    def get_location(labels)
      attrs = {}
      labels.each do |attr, val|
        if attr =~ /traefik.http.routers.([^\.]+).rule/
          service = $1
          if val =~ /Host\(`(.+)`\)/
            attrs[service] = Location.new($1)
          else
            puts "Unknown rule #{val} for service #{service}"
          end
        end
      end
      attrs
    rescue
      {}
    end

    def publish(router, location)
      puts "Publishing #{router} #{location}"

      dest = BUS.service("org.freedesktop.Avahi")
      obj = dest.object("/")
      int = obj["org.freedesktop.Avahi.Server"]
      reply = int.EntryGroupNew

      group = dest.object(reply[0].to_s)
      group_int = group["org.freedesktop.Avahi.EntryGroup"]
      require 'pp'
      pp [@interface, -1, 16, location.name, @address]
      resp = group_int.AddAddress(@interface, -1, 16, location.name, @address)
      puts resp unless resp.empty?
      resp = group_int.Commit
      puts resp unless resp.empty?

      @published[router] = group
    end

    def unpublish(router, location)
      puts "Unpublishing #{router} #{location}"

      group = @published.delete(router)
      if group.nil?
        puts "Missing entry"
        return
      end
      group_int = group["org.freedesktop.Avahi.EntryGroup"]
      group_int.Reset
      group_int.Free
    end

    private def resolve_avahi_interface(interface)
      dest = BUS.service("org.freedesktop.Avahi")
      obj = dest.object("/")
      int = obj["org.freedesktop.Avahi.Server"]
      int_num = int.GetNetworkInterfaceIndexByName(interface)[0]
      puts("Interface #{interface} is avahi number #{int_num}")
      int_num
    end

    private def find_interface_address(interface)
      interfaces = Socket.getifaddrs
      require 'pp'
      pp interfaces
      puts "Found #{interfaces.size} addresses"
      ip = interfaces.select {|int| int.name == interface }.map(&:addr).detect(&:ipv4?).ip_address
      puts "Using ip #{ip}"
      ip
    end

    private def int_to_ip(i)
      "#{i % 256}.#{(i >> 8) % 256}.#{(i >> 16) % 256}.#{(i >> 24) % 256}"
    end
  end
end
