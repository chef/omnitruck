require 'spec_helper'
require 'json'

context 'Chef::VersionResolver' do
  let(:build_map) { JSON.parse(File.read(File.join(SPEC_DATA, 'current', 'build-chef-list.json'))) }

  let(:input_version) { 'latest' }
  let(:input_platform) { 'ubuntu' }
  let(:input_platform_version) { '14.04' }
  let(:input_machine_architecture) { 'i686' }

  let(:version_resolver) {
    Chef::VersionResolver.new(input_version, build_map,
                              platform_string: input_platform,
                              platform_version_string: input_platform_version,
                              machine_string: input_machine_architecture)
  }

  context 'find_available_distro_versions' do
    context 'for invalid platform' do
      let(:input_platform) { 'benthos' }

      it 'fails' do
        expect{version_resolver.find_available_distro_versions}.to raise_error(Chef::VersionResolver::InvalidPlatform)
      end
    end

    context 'for ubuntu 14.04' do
      it 'selects and sorts all versions for correct parameters' do
        available_distros = version_resolver.find_available_distro_versions

        expect(available_distros.length).to eq(3)

        # we need to peek into the relpath to check the correct sorting
        expect(available_distros[0]['i686']['11.18.14+20150905090307-1']['relpath']).to match(/10.04/)
        expect(available_distros[1]['i686']['11.18.14+20150905090307-1']['relpath']).to match(/12.04/)
        expect(available_distros[2]['i686']['11.18.14+20150905090307-1']['relpath']).to match(/14.04/)
      end
    end

    context 'for ubuntu 12.04' do
      let(:input_platform_version) { '12.04' }

      it 'selects and sorts versions only platform versions <= version we are looking for' do
        available_distros = version_resolver.find_available_distro_versions

        expect(available_distros.length).to eq(2)

        # we need to peek into the relpath to check the correct sorting
        expect(available_distros[0]['i686']['11.18.14+20150905090307-1']['relpath']).to match(/10.04/)
        expect(available_distros[1]['i686']['11.18.14+20150905090307-1']['relpath']).to match(/12.04/)
      end
    end

    context 'for ubuntu 08.04' do
      let(:input_platform_version) { '08.04' }

      it 'fails when there are no available distro versions' do
        expect{version_resolver.find_available_distro_versions}.to raise_error(Chef::VersionResolver::InvalidDownloadPath)
      end
    end
  end

  context 'find_available_versions' do
    context 'for ubuntu 14.04' do
      it 'only selects matching architecture versions' do
        expect(version_resolver.find_available_versions.length).to eq(14)
      end
    end
  end

  context 'package_info' do
    # package selection is extensively tested under opscode/version_spec
    # here we only test to see if the output is correctly formatted
    it 'returns all the metadata and version' do
      info = version_resolver.package_info
      expect(info).to be_a(Hash)
      expect(info).to have_key('relpath')
      expect(info).to have_key('md5')
      expect(info).to have_key('sha256')
      expect(info).to have_key('version')
    end
  end

end
