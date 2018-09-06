module Yao::Resources
  class NetworkingFloatingIP < Base
    friendly_attributes :floating_network_id, :floating_ip_address, :port_id

    self.service        = "network"
    self.resource_name  = "floatingip"
    self.resources_name = "floatingips"
  end
end
