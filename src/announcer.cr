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
require "dbus/introspect"

module DockerMdns
  struct Location
    property name

    def initialize(@name : String)
    end
  end

  class Announcer
    @@bus = DBus::Bus.new(DBus::BusType::SYSTEM)
    @@published = {} of String => DBus::Object

    @interface : Int32
    @address : String

    def initialize(interface : String)
      @interface = resolve_avahi_interface(interface)
      @address = find_interface_address(interface)
    end

    def process(event)
      if event["Action"] == "start"
        get_location(event["Actor"]["Attributes"].as_h).each do |router, location|
          publish(router, location)
        end
      elsif event["Action"] == "die"
        get_location(event["Actor"]["Attributes"].as_h).each do |router, location|
          unpublish(router, location)
        end
      end
    end

    def process_existing(containers)
      containers.each do |container|
        get_location(container["Labels"].as_h).each do |router, location|
          publish(router, location)
        end
      end
    end

    def get_location(labels)
      attrs = {} of String => Location
      labels.each do |attr, val|
        if attr =~ /traefik.http.routers.([^\.]+).rule/
          service = $1
          if val.as_s =~ /Host\(`(.+)`\)/
            attrs[service] = Location.new(name: $1)
          else
            puts "Unknown rule #{val} for service #{service}"
          end
        end
      end
      attrs
    rescue
      {} of String => Location
    end

    def publish(router, location)
      puts "Publishing #{router} #{location}"

      dest = @@bus.destination("org.freedesktop.Avahi")
      obj = dest.object("/")
      int = obj.interface("org.freedesktop.Avahi.Server")
      reply = int.call("EntryGroupNew").reply

      group = dest.object(reply[0].to_s)
      group_int = group.interface("org.freedesktop.Avahi.EntryGroup")
      resp = group_int.call("AddAddress", [@interface, -1, 16u32, location.name, @address]).reply
      puts resp unless resp.empty?
      resp = group_int.call("Commit").reply
      puts resp unless resp.empty?

      @@published[router] = group
    end

    def unpublish(router, location)
      puts "Unpublishing #{router} #{location}"

      group = @@published.delete(router)
      if group.nil?
        puts "Missing entry"
        return
      end
      group_int = group.interface("org.freedesktop.Avahi.EntryGroup")
      group_int.call("Reset")
      group_int.call("Free")
    end

    private def resolve_avahi_interface(interface) : Int32
      dest = @@bus.destination("org.freedesktop.Avahi")
      obj = dest.object("/")
      int = obj.interface("org.freedesktop.Avahi.Server")
      int_num = int.call("GetNetworkInterfaceIndexByName", [interface]).reply[0]
      puts("Interface #{interface} is avahi number #{int_num}")
      int_num.as(Int32)
    end

    private def find_interface_address(interface) : String
      dest = @@bus.destination("org.freedesktop.NetworkManager")
      path = dest.object("/org/freedesktop/NetworkManager").interface("org.freedesktop.NetworkManager").call("GetDeviceByIpIface", [interface]).reply[0]
      puts("Interface path #{path}")

      ip4conf = dest.object(path.as(String)).interface("org.freedesktop.NetworkManager.Device").get("Ip4Config").reply[0].as(DBus::Variant)
      addresses = dest.object(ip4conf.value.as(String)).interface("org.freedesktop.NetworkManager.IP4Config").get("Addresses").reply
      puts "Found #{addresses.size} addresses"
      ipint = addresses[0].as(DBus::Variant).value.as(Array(DBus::Type))[0].as(Array(DBus::Type))[0].as(UInt32)
      addr = int_to_ip(ipint)
      puts "Using ip #{addr}"
      addr
    end

    private def int_to_ip(i : UInt32) : String
      "#{i % 256}.#{(i >> 8) % 256}.#{(i >> 16) % 256}.#{(i >> 24) % 256}"
    end
  end
end
