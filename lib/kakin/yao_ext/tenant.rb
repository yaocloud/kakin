require 'yao/resources/tenant'

module Yao::Resources
  class Tenant < Base
    def network_usage(ip_regexp, type, start_time, end_time)
      servers.inject(0) do |t, server|
        samples = server.old_samples(counter_name: "network.#{type}.bytes", query: {'q.field': 'timestamp', 'q.op': 'gt', 'q.value': start_time})
        if samples.empty?
          t
        else
          wan_samples = samples.select{|s| s.resource_metadata["mac"] == server.mac_address(ip_regexp) }.sort_by(&:timestamp)
          if wan_samples.empty?
            t
          else
            last_sample_index = wan_samples.find_index{|s| s.timestamp > Time.parse(end_time) }
            if last_sample_index
              t + (wan_samples[last_sample_index].counter_volume - wan_samples[0].counter_volume)
            else
              t + (wan_samples[-1].counter_volume - wan_samples[0].counter_volume)
            end
          end
        end
      end
    end
  end
end
