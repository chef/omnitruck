require 'spec_helper'

describe Chef::Project do
  let(:channel) { double('channel') }
  let(:project) { described_class.new('myproject', channel) }

  describe '#release_manifest_name' do
    it 'returns the proper release manifest name' do
      expect(project.release_manifest_name).to eq('myproject-release-manifest')
    end
  end

  describe '#manifests' do
    let(:channel_manifests) do
      [
        'manifest_key/key1',
        'manifest_key/key2',
        'manifest_key/key3',
        'haha-what-is-this/key4',
        'seriously-what-are-you-doing-here/key5'
      ]
    end

    it 'returns manifests that only match the release manifest name' do
      allow(channel).to receive(:manifests).and_return(channel_manifests)
      allow(project).to receive(:release_manifest_name).and_return('manifest_key')
      expect(project.manifests).to eq(%w(key1 key2 key3))
    end
  end

  describe '#get_platform_names' do
    it 'returns the downloaded manifest if it exists' do
      allow(project).to receive(:key_for).and_return('manifest_key')
      expect(channel).to receive(:download_manifest).with('manifest_key').and_return('platform_names')
      expect(project.get_platform_names).to eq('platform_names')
    end

    it 'returns an empty JSON blob if the manifest file cannot be found' do
      allow(project).to receive(:key_for).and_return('manifest_key')
      expect(channel).to receive(:download_manifest).with('manifest_key').and_raise(Chef::Channel::ManifestNotFound)
      expect(project.get_platform_names).to eq('{}')
    end
  end
end
