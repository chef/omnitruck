require 'spec_helper'

describe Chef::Channel do
  let(:channel) { described_class.new('test_channel', 'metadata_bucket', 'packages_bucket') }

  before do
    # squelch debug output during tests
    allow(channel).to receive(:debug)
  end

  describe '#manifests' do
    it 'populates the manifest_metadata hash correctly' do
      allow(channel.s3).to receive(:fetch).and_yield('key1', 'md5_1', 'date1').and_yield('key2', 'md5_2', 'date2')

      channel.manifests
      expect(channel.manifest_metadata['key1']).to eq({ md5: 'md5_1', last_modified: 'date1'})
      expect(channel.manifest_metadata['key2']).to eq({ md5: 'md5_2', last_modified: 'date2'})
    end

    it 'only returns .json files and no platform-names files' do
      allow(channel.s3).to receive(:fetch).and_yield('key1.json', 'md5', 'date')
                                          .and_yield('key2.json', 'md5', 'date')
                                          .and_yield('key3.json', 'md5', 'date')
                                          .and_yield('test-platform-names.json', 'md5', 'date')
                                          .and_yield('fake-file.txt', 'md5', 'date')

      expect(channel.manifests).to eq(%w(key1.json key2.json key3.json))
    end
  end

  describe '#download_manifest' do
    it 'fetches the manifest provided' do
      allow(channel).to receive(:s3_url_for_manifest).with('test_manifest').and_return('test_url')

      expect(RestClient).to receive(:get).with('test_url')
      channel.download_manifest('test_manifest')
    end

    context 'when a RestClient exception is raised' do
      let(:exception) { RestClient::Exception.new }

      it 'raises a ManifestNotFound exception if the http code is a 404' do
        allow(channel).to receive(:s3_url_for_manifest).with('test_manifest').and_return('test_url')
        allow(RestClient).to receive(:get).with('test_url').and_raise(exception)
        allow(exception).to receive(:http_code).and_return(404)

        expect { channel.download_manifest('test_manifest') }.to raise_error(Chef::Channel::ManifestNotFound)
      end

      it 'raises the received exception if the http code is not 404' do
        allow(channel).to receive(:s3_url_for_manifest).with('test_manifest').and_return('test_url')
        allow(RestClient).to receive(:get).with('test_url').and_raise(exception)
        allow(exception).to receive(:http_code).and_return(500)

        expect { channel.download_manifest('test_manifest') }.to raise_error(RestClient::Exception)
      end
    end
  end

  describe '#s3_url_for_manifest' do
    it 'returns a properly formatted s3 URL' do
      expect(channel.s3_url_for_manifest('test+key')).to eq('https://metadata_bucket.s3.amazonaws.com/test%2Bkey')
    end
  end

  describe '#manifest_md5_for' do
    it 'returns nil if the key is not found' do
      allow(channel).to receive(:manifest_metadata).and_return({})
      expect(channel.manifest_md5_for('test_key')).to eq(nil)
    end

    it 'returns the md5 if the key is found' do
      allow(channel).to receive(:manifest_metadata).and_return({ 'test_key' => { md5: 'test_md5' } })
      expect(channel.manifest_md5_for('test_key')).to eq('test_md5')
    end
  end

  describe '#manifest_last_modified_for' do
    it 'returns nil if the key is not found' do
      allow(channel).to receive(:manifest_metadata).and_return({})
      expect(channel.manifest_last_modified_for('test_key')).to eq(nil)
    end

    it 'returns the md5 if the key is found' do
      allow(channel).to receive(:manifest_metadata).and_return({ 'test_key' => { last_modified: 'test_date' } })
      expect(channel.manifest_last_modified_for('test_key')).to eq('test_date')
    end
  end
end
