module Yao
  def self.tenant_klass
    Yao.keystone_v2? ? Yao::Tenant : Yao::Project
  end

  # @return [Bool]
  def self.keystone_v2?
    Yao.default_client.pool["identity"].url_prefix.to_s.match(/v2\.0/)
  end
end
