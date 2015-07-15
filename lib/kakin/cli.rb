require 'date'
require 'yaml'
require 'json'
require 'net/http'
require 'fog'
require 'thor'

module Kakin
  class CLI <Thor
    default_command :calc

    option :f, type: :string, banner: "<file>", desc: "cost define file(yaml)", required: true
    option :s, type: :string, banner: "<start>", desc: "start time", default: (DateTime.now << 1).strftime("%Y-%m-01")
    option :e, type: :string, banner: "<end>", desc: "end time", default: Time.now.strftime("%Y-%m-01")
    desc 'calc', 'Calculate the cost'
    def calc
      cost = YAML.load_file(options[:f])
      start_time = Time.parse(options[:s]).strftime("%FT%T")
      end_time = Time.parse(options[:e]).strftime("%FT%T")

      STDERR.puts "Start: #{start_time}"
      STDERR.puts "End:   #{end_time}"

      credentials = Fog::Identity[:openstack].credentials
      endpoint = "http://#{URI(credentials[:openstack_management_url]).hostname}:8774"
      url = URI.parse("#{endpoint}/v2/#{credentials[:current_tenant]["id"]}/os-simple-tenant-usage?start=#{start_time}&end=#{end_time}")

      req = Net::HTTP::Get.new(url)
      req["Accept"] = "application/json"
      req["X-Auth-Token"] = credentials[:openstack_auth_token]
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      
      if res.code != "200"
        raise "usage data fatch is failed"
      else
        result = Hash.new
        JSON.load(res.body)["tenant_usages"].each do |usage|
          tenant = Fog::Identity[:openstack].get_tenants_by_id(usage["tenant_id"])
          tenant_name = tenant.body["tenant"]["name"]

          total_vcpus_usage     = usage["total_vcpus_usage"]
          total_memory_mb_usage = usage["total_memory_mb_usage"]
          total_local_gb_usage  = usage["total_local_gb_usage"]

          bill_vcpu   = total_vcpus_usage * cost["vcpu_per_hour"]
          bill_memory = total_memory_mb_usage * cost["memory_mb_per_hour"]
          bill_disk   = total_local_gb_usage * cost["disk_gb_per_hour"]

          result[tenant_name] = {
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
  end
end
