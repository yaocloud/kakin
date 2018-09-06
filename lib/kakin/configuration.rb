module Kakin
  class Configuration

    def self.management_url
      @@_management_url
    end

    def self.tenant
      @@_tenant
    end

    def self.setup
      yaml = YAML.load_file(File.expand_path('~/.kakin'))

      @@_management_url = yaml['management_url']
      @@_tenant = yaml['tenant']

      Yao.configure do
        auth_url yaml['auth_url']
        tenant_name yaml['tenant']
        username yaml['username']
        password yaml['password']
        timeout yaml['timeout'] if yaml['timeout']
        client_cert yaml['client_cert'] if yaml['client_cert']
        client_key yaml['client_key'] if yaml['client_key']
      end
    end
  end
end
