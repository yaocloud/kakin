module Yao
# @return [Bool]
  def self.keystone_v2?
    Yao.default_client.pool["identity"].url_prefix.to_s.match(/v2\.0/)
  end
end