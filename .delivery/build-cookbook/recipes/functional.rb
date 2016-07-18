# WIP/TEMP We only want this pipeline to support an acceptance environment
return unless node['delivery']['change']['stage'] == 'acceptance'

include_recipe 'chef-sugar::default'

load_delivery_chef_config

site_name = 'omnitruck'
domain_name = 'chef.io'

if node['delivery']['change']['stage'] == 'delivered'
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  fqdn = "#{site_name}.#{domain_name}"
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}2"
  fqdn = "#{site_name}-#{node['delivery']['change']['stage']}2.#{domain_name}"
end

ruby_block 'check some things we broke' do
  block do
    require 'net/http'
    URI("https://#{fqdn}/chef/metadata-chefdk?p=ubuntu&pv=12.04&m=x86_64").tap do |uri|
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 200
        fail "GET #{uri} returned #{response.code.to_i} instead of a 200"
      end
    end

    # Legacy endpoints that are not real should 404
    URI("https://#{fqdn}/chef/metadata-foo?p=ubuntu&pv=12.04&m=x86_64").tap do |uri|
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 404
        fail "GET #{uri} returned #{response.code.to_i} instead of a 404"
      end
    end
  end
end
