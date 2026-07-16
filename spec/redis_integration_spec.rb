require 'spec_helper'

RSpec.describe 'Redis-backed integration', :redis_integration do
  def app
    Omnitruck
  end

  json_accept = { 'HTTP_ACCEPT' => 'application/json' }.freeze

  before do
    skip 'Set OMNITRUCK_USE_REAL_REDIS=1 to run Redis integration specs' unless ENV['OMNITRUCK_USE_REAL_REDIS'] == '1'
  end

  it 'reads populated manifests from Redis through Chef::Cache' do
    manifest = Chef::Cache.new.manifest_for('chef', 'stable')

    expect(manifest).to be_a(Hash)
    expect(manifest.fetch('run_data')).to include('timestamp')
  end

  it 'serves metadata through the Redis-backed cache' do
    get '/stable/chef/metadata', { p: 'el', pv: '7', m: 'x86_64' }, json_accept

    expect(last_response).to be_ok

    data = JSON.parse(last_response.body)
    expect(data.fetch('version')).not_to be_empty
    expect(data.fetch('url')).to include('/stable/chef/')
  end
end
