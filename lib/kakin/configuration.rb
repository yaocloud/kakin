module Kakin
  class Configuration

    def self.tenant
      @@_tenant
    end

    def self.setup
      config = {
        'auth_url'             => ENV['OS_AUTH_URL'],
        'tenant'               => ENV['OS_TENANT_NAME'] || ENV['OS_PROJECT_NAME'],
        'username'             => ENV['OS_USERNAME'],
        'password'             => ENV['OS_PASSWORD'],
        'client_cert'          => ENV['OS_CERT'],
        'client_key'           => ENV['OS_KEY'],
        'identity_api_version' => ENV['OS_IDENTITY_API_VERSION'],
        'user_domain_name'     => ENV['OS_USER_DOMAIN_NAME'],
        'project_domain_name'  => ENV['OS_PROJECT_DOMAIN_NAME'],
        'timeout'              => ENV['YAO_TIMEOUT'],
        'management_url'       => ENV['YAO_MANAGEMENT_URL'],
        'debug'                => ENV['YAO_DEBUG'] || false,
      }

      file_path = File.expand_path('~/.kakin')
      if File.exist?(file_path)
        yaml = YAML.load_file(file_path)
        config.merge!(yaml)
      end

      @@_tenant = config['tenant']

      Yao.configure do
        auth_url config['auth_url']
        tenant_name config['tenant']
        username config['username']
        password config['password']
        timeout config['timeout'].to_i if config['timeout']
        client_cert config['client_cert'] if config['client_cert']
        client_key config['client_key'] if config['client_key']
        identity_api_version config['identity_api_version'] if config['identity_api_version']
        user_domain_name config['user_domain_name'] if config['user_domain_name']
        project_domain_name config['project_domain_name'] if config['project_domain_name']
        debug config['debug']
      end
    end
  end
end
