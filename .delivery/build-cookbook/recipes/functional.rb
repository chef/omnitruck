include_recipe 'chef-sugar::default'

site_name = 'omnitruck'
domain_name = 'chef.io'

if node['delivery']['change']['stage'] == 'delivered'
  bucket_name = node['delivery']['change']['project'].gsub(/_/, '-')
  fqdn = "#{site_name}.#{domain_name}"
else
  bucket_name = "#{node['delivery']['change']['project'].gsub(/_/, '-')}-#{node['delivery']['change']['stage']}"
  fqdn = "#{site_name}-#{node['delivery']['change']['stage']}.#{domain_name}"
end

ruby_block 'check some things we broke' do
  block do
    require 'net/http'

    endpoints = [
      "/_status",
      "/install.sh",
      "/install.ps1",
    ]

    endpoints.each do |dest|
      URI("https://#{fqdn}#{dest}").tap do |uri|
        response = Net::HTTP.get_response(uri)
        unless response.code.to_i == 200
          fail "GET #{uri} returned #{response.code.to_i} instead of a 200"
        end
      end
    end
  end
end
