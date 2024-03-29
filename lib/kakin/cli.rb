require 'date'
require 'yaml'
require 'json'
require 'net/http'
require 'yao'
require 'kakin/yao_ext/yao'
require 'kakin/yao_ext/tenant'
require 'kakin/yao_ext/server'
require 'thor'

module Kakin
  class CLI <Thor
    default_command :calc

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :s, type: :string, banner: "<start>", desc: "start time", default: (DateTime.now << 1).strftime("%Y-%m-01")
    option :e, type: :string, banner: "<end>", desc: "end time", default: Time.now.strftime("%Y-%m-01")
    option :t, type: :array, banner: "<tenant>", desc: "specify tenants"
    option :S, type: :array, banner: "<tenant>", desc: "skip tenants", default: []
    desc 'calc', 'Calculate the cost'
    def calc
      Kakin::Configuration.setup

      yaml = YAML.load_file(options[:f])
      start_time = Time.parse(options[:s]).strftime("%FT%T")
      end_time = Time.parse(options[:e]).strftime("%FT%T")
      skip = options[:S]
      tenants = if tenants = options[:t]
        tenants.map do |tenant|
          Yao.tenant_klass.get(tenant)
        end
      else
        Yao.tenant_klass.list
      end.select do |tenant|
        name = tenant.name || tenant.id
        !skip.include?(name)
      end

      STDERR.puts "Start: #{start_time}"
      STDERR.puts "End:   #{end_time}"

      result = tenants.each_with_object({}) do |tenant, result|
        usage = tenant.server_usage(start: start_time, end: end_time)
        next if usage.empty?

        total_vcpus_usage     = usage["total_vcpus_usage"]
        total_memory_mb_usage = usage["total_memory_mb_usage"]
        total_local_gb_usage  = usage["total_local_gb_usage"]

        bill_vcpu   = total_vcpus_usage * yaml["vcpu_per_hour"]
        bill_memory = total_memory_mb_usage * yaml["memory_mb_per_hour"]
        bill_disk   = total_local_gb_usage * yaml["disk_gb_per_hour"]

        name = tenant.name || tenant.id
        result[name] = {
          'bill_total'            => bill_vcpu + bill_memory + bill_disk,
          'bill_vcpu'             => bill_vcpu,
          'bill_memory'           => bill_memory,
          'bill_disk'             => bill_disk,
          'total_hours'           => usage["total_hours"],
          'total_vcpus_usage'     => total_vcpus_usage,
          'total_memory_mb_usage' => total_memory_mb_usage,
          'total_local_gb_usage'  => total_local_gb_usage,
        }
      end

      puts YAML.dump(result)
    end

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :s, type: :string, banner: "<start>", desc: "start time", default: (DateTime.now << 1).strftime("%Y-%m-01")
    option :e, type: :string, banner: "<end>", desc: "end time", default: Time.now.strftime("%Y-%m-01")
    option :t, type: :string, banner: "<tenant>", desc: "specify tenant", default: ""
    desc 'network', 'network resource'
    def network
      Kakin::Configuration.setup

      yaml = YAML.load_file(options[:f])
      start_time = Time.parse(options[:s])
      end_time = Time.parse(options[:e])

      STDERR.puts "Start: #{start_time}"
      STDERR.puts "End:   #{end_time}"

      result = Hash.new
      tenants = unless options[:t].empty?
                  Yao.tenant_klass.list(name: options[:t])
                else
                  Yao.tenant_klass.list
                end
      tenants = [tenants] unless tenants.is_a?(Array)

      tenants.each do |tenant|
        incoming = tenant.network_usage(Regexp.new(yaml["ip_regexp"]), :incoming, start_time.iso8601, end_time.iso8601)
        outgoing = tenant.network_usage(Regexp.new(yaml["ip_regexp"]), :outgoing, start_time.iso8601, end_time.iso8601)
        result[tenant.name] = {
          'incoming_usage'  => incoming,
          'outgoing_usage'  => outgoing,
          'total_usage'     => incoming + outgoing
        }
      end

      puts YAML.dump(result)
    end

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :t, type: :string, banner: "<tenant>", desc: "specify tenant", default: ""
    desc 'ip', 'ip use count'
    def ip
      Kakin::Configuration.setup

      yaml = YAML.load_file(options[:f])
      ip_regexp = Regexp.new(yaml["ip_regexp"])

      result = Hash.new
      tenants = unless options[:t].empty?
                  Yao.tenant_klass.list(name: options[:t])
                else
                  Yao.tenant_klass.list
                end
      tenants = [tenants] unless tenants.is_a?(Array)

      tenants.each do |tenant|
        count = tenant.ports.select {|p| p.fixed_ips[0]["ip_address"] =~ ip_regexp}.count
        count += Yao::FloatingIP.list(tenant_id: tenant.id).select {|p| p.floating_ip_address =~ ip_regexp}.count
        result[tenant.name] = {
          'count'       => count,
          'total_usage' => count * yaml["cost_per_ip"],
        }
      end

      puts YAML.dump(result)
    end

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :t, type: :string, banner: "<tenant>", desc: "specify tenant", default: ""
    desc 'volume', 'volume usage'
    def volume
      Kakin::Configuration.setup
      yaml = YAML.load_file(options[:f])

      result = Hash.new
      tenants = unless options[:t].empty?
                  Yao.tenant_klass.list(name: options[:t])
                else
                  Yao.tenant_klass.list
                end
      tenants = [tenants] unless tenants.is_a?(Array)
      volume_types = Yao::VolumeType.list
      volumes = Yao::Volume.list_detail(all_tenants: true)

      tenants.each do |tenant|
        result[tenant.name] ||= {}
        volume_types.each do |volume_type|
          count = volumes.select { |volume| volume.tenant_id == tenant.id && volume.volume_type == volume_type.name }.map(&:size).sum
          result[tenant.name][volume_type.name] = {
              'count': count,
              'total_usage': count * yaml['volume_cost_per_gb'][volume_type.name]
          }
        end
      end

      puts YAML.dump(result)
    end
  end
end
