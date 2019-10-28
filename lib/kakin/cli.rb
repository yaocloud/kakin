require 'date'
require 'yaml'
require 'json'
require 'net/http'
require 'yao'
require 'kakin/yao_ext/yao'
require 'kakin/yao_ext/tenant'
require 'kakin/yao_ext/server'
require 'kakin/yao_ext/floatingip'
require 'thor'

module Kakin
  class CLI <Thor
    default_command :calc

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :s, type: :string, banner: "<start>", desc: "start time", default: (DateTime.now << 1).strftime("%Y-%m-01")
    option :e, type: :string, banner: "<end>", desc: "end time", default: Time.now.strftime("%Y-%m-01")
    option :t, type: :string, banner: "<tenant>", desc: "specify tenant", default: ""
    desc 'calc', 'Calculate the cost'
    def calc
      Kakin::Configuration.setup

      yaml = YAML.load_file(options[:f])
      start_time = Time.parse(options[:s]).strftime("%FT%T")
      end_time = Time.parse(options[:e]).strftime("%FT%T")

      STDERR.puts "Start: #{start_time}"
      STDERR.puts "End:   #{end_time}"
      client = Yao.default_client.pool['compute']
      tenant_id = get_tenant.id
      res = client.get("./os-simple-tenant-usage?start=#{start_time}&end=#{end_time}") do |req|
        req.headers["Accept"] = "application/json"
      end

      if res.status != 200
        raise "usage data fatch is failed"
      else
        result = Hash.new
        tenant_usages = res.body["tenant_usages"]
        tenants = list_tenant

        unless options[:t].empty?
          tenant = tenants.find { |tenant| tenant.name == options[:t] }
          raise "Not Found tenant #{options[:t]}" unless tenant

          tenant_usages = tenant_usages.select { |tenant_usage| tenant_usage["tenant_id"] == tenant.id }
        end

        tenant_usages.each do |usage|
          tenant = tenants.find { |tenant| tenant.id == usage["tenant_id"] }

          total_vcpus_usage     = usage["total_vcpus_usage"]
          total_memory_mb_usage = usage["total_memory_mb_usage"]
          total_local_gb_usage  = usage["total_local_gb_usage"]

          bill_vcpu   = total_vcpus_usage * yaml["vcpu_per_hour"]
          bill_memory = total_memory_mb_usage * yaml["memory_mb_per_hour"]
          bill_disk   = total_local_gb_usage * yaml["disk_gb_per_hour"]

          result[tenant.name] = {
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
                  list_tenant(name: options[:t])
                else
                  list_tenant
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
                  list_tenant(name: options[:t])
                else
                  list_tenant
                end
      tenants = [tenants] unless tenants.is_a?(Array)

      tenants.each do |tenant|
        count = tenant.ports.select {|p| p.fixed_ips[0]["ip_address"] =~ ip_regexp}.count
        count += Yao::NetworkingFloatingIP.list(tenant_id: tenant.id).select {|p| p.floating_ip_address =~ ip_regexp}.count
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
                  list_tenant(name: options[:t])
                else
                  list_tenant
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

def get_tenant
  if Yao.keystone_v2?
    Yao::Tenant.get(Kakin::Configuration.tenant)
  else
    Yao::Project.get(Kakin::Configuration.tenant)
  end
end

def list_tenant(query={})
  if Yao.keystone_v2?
    Yao::Tenant.list(query)
  else
    Yao::Project.list(query)
  end
end
