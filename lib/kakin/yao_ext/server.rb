require 'yao/resources/server'

module Yao::Resources
  class Server < Base
    def mac_address(ip_regexp)
      port = addresses.select{|_, v| v[0]["addr"] =~ ip_regexp}
      port.empty? ? nil : port.values[0][0]["OS-EXT-IPS-MAC:mac_addr"]
    end
  end
end
