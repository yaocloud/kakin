module Yao::Resources
  class Tenant < Base
    def network_usage(type, start_time, end_time)
      servers.inject(0) do |t, server|
        samples = server.old_samples(counter_name: "network.#{type}.bytes", query: {'q.field': 'timestamp', 'q.op': 'gt', 'q.value': start_time}).sort_by(&:timestamp)
        if samples.empty?
          t
        else
          last_sample_index = samples.find_index{|s| s.timestamp > Time.parse(end_time) }
          if last_sample_index
            t + (samples[last_sample_index].counter_volume - samples[0].counter_volume)
          else
            t + (samples[-1].counter_volume - samples[0].counter_volume)
          end
        end
      end
    end
  end
end
