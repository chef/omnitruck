return if (workflow_stage?('union') || workflow_stage?('rehearsal'))

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

ruby_block 'check for a 200' do
  block do
    require 'rspec'
    require 'net/http'

    RSpec.describe "Omnitruck API" do
      it 'install.sh should return 200 over http' do
        uri = URI("http://#{fqdn}/install.sh")
        response = Net::HTTP.get_response(uri)
        expect(response.code.to_i).to eq(200)
      end

      it 'install.sh should return 200 over https' do
        uri = URI("https://#{fqdn}/install.sh")
        response = Net::HTTP.get_response(uri)
        expect(response.code.to_i).to eq(200)
      end
    end
  end
end
