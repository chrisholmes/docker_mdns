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

require "./docker_sock"
require "./announcer"

module DockerMdns
  VERSION = "0.1.0"
  STDOUT.sync = true

  interface = ARGV[0]

  announcer = Announcer.new(interface)

  puts "Processing existing services"
  announcer.process_existing(DockerSock.new.list_containers)

  puts "Processing new services"
  DockerSock.new.stream_events do |event|
    if event["Type"] != "container"
      next
    end
    announcer.process(event)
  end
end
