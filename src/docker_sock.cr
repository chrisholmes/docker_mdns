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

require "socket"
require "json"
require "http/headers"
require "http/request"
require "http/client/response"

module DockerMdns
  class DockerSock
    def initialize
      @sock = UNIXSocket.new("/var/run/docker.sock")
    end

    def stream_events
      req = HTTP::Request.new("GET", "/events", HTTP::Headers{"Host" => "Docker"})
      req.to_io(@sock)

      HTTP::Client::Response.from_io?(@sock) do |resp|
        raise "Docker events not available" if resp.nil?
        while true
          yield JSON.parse(resp.body_io.read_line)
        end
      end
    end

    def list_containers
      req = HTTP::Request.new("GET", "/containers/json", HTTP::Headers{"Host" => "Docker"})
      req.to_io(@sock)

      resp = HTTP::Client::Response.from_io(@sock)
      JSON.parse(resp.body).as_a
    end
  end
end
