require 'date'
require 'yaml'
require 'json'
require 'net/http'
require 'yao'
require 'kakin/yao_ext/tenant'
require 'kakin/yao_ext/server'
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
      url = URI.parse("#{Kakin::Configuration.management_url}/#{Yao::Tenant.get_by_name(Kakin::Configuration.tenant).id}/os-simple-tenant-usage?start=#{start_time}&end=#{end_time}")
      req = Net::HTTP::Get.new(url)
      req["Accept"] = "application/json"
      req["X-Auth-Token"] = Yao::Auth.try_new.token
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }

      if res.code != "200"
        raise "usage data fatch is failed"
      else
        result = Hash.new
        tenant_usages = JSON.load(res.body)["tenant_usages"]
        tenants = Yao::Tenant.list

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
                  Yao::Tenant.list(name: options[:t])
                else
                  Yao::Tenant.list
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
                  Yao::Tenant.list(name: options[:t])
                else
                  Yao::Tenant.list
                end
      tenants = [tenants] unless tenants.is_a?(Array)

      tenants.each do |tenant|
        count = tenant.ports.select {|p| p.fixed_ips[0]["ip_address"] =~ ip_regexp}.count
        result[tenant.name] = {
          'count'       => count,
          'total_usage' => count * yaml["cost_per_ip"],
        }
      end

      puts YAML.dump(result)
    end
  end
end
