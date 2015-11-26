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
      end
    end
  end
end
