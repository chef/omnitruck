require 'spec_helper'
require 'opscode/version'

context 'Opscode::Version' do
  def self.version_resolution_case(expected, version_list)
    context "with #{version_list.join(' & ')}" do
      let(:resolved_version) do
        v = version.nil? ? version : Opscode::Version.parse(version)
        Opscode::Version.find_target_version(available_versions, v, true)
      end

      let(:available_versions) { version_list.map { |v| Opscode::Version.parse(v) } }

      it "selects #{expected}" do
        expect(resolved_version.to_s).to eq(expected)
      end
    end
  end

  shared_examples_for 'correct version resolution' do
    version_resolution_case('12.1.2+20150906090309', %w{12.1.2 12.1.2+20150906090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2 12.1.2+20150906090309-1})
    version_resolution_case('12.1.2+20150906090309', %w{12.1.2-1 12.1.2+20150906090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2-1 12.1.2+20150906090309-1})
    version_resolution_case('12.1.2-1', %w{12.1.2-1 12.1.2})
    version_resolution_case('12.1.2-2', %w{12.1.2-1 12.1.2-2})
    version_resolution_case('12.1.2+20150906090309', %w{12.1.2+20150906090309 12.1.2+20150905090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2+20150906090309-1 12.1.2+20150906090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2+20150906090309-1 12.1.2+20150905090309-1})
    version_resolution_case('12.1.2+20150906090309-2', %w{12.1.2+20150906090309-1 12.1.2+20150906090309-2})
  end

  context 'resolving with input :latest' do
    # setting version to nil is equivalent to searching for :latest
    let(:version) { nil }

    it_behaves_like 'correct version resolution'

    version_resolution_case('13.1.2', %w{12.1.2 13.1.2})
    version_resolution_case('12.2.2', %w{12.1.2 12.2.2})
    version_resolution_case('12.1.3', %w{12.1.2 12.1.3})
  end

  context 'resolving with input 12' do
    let(:version) { '12' }

    it_behaves_like 'correct version resolution'

    version_resolution_case('12.1.2', %w{12.1.2 13.1.2})
  end

  context 'resolving with input 12.1' do
    let(:version) { '12.1' }

    it_behaves_like 'correct version resolution'

    version_resolution_case('12.1.2', %w{12.1.2 13.1.2})
    version_resolution_case('12.1.2', %w{12.1.2 12.2.2})
    version_resolution_case('12.1.3', %w{12.1.2 12.1.3})
  end

  context 'resolving with input 12.1.2' do
    let(:version) { '12.1.2' }

    version_resolution_case('12.1.2', %w{12.1.2 12.1.2+20150906090309})
    version_resolution_case('12.1.2', %w{12.1.2 12.1.2+20150906090309-1})
    version_resolution_case('12.1.2-1', %w{12.1.2-1 12.1.2+20150906090309})
    version_resolution_case('12.1.2-1', %w{12.1.2-1 12.1.2+20150906090309-1})
    version_resolution_case('12.1.2', %w{12.1.2-1 12.1.2})
    version_resolution_case('12.1.2-2', %w{12.1.2-1 12.1.2-2})
    version_resolution_case('12.1.2+20150906090309', %w{12.1.2+20150906090309 12.1.2+20150905090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2+20150906090309-1 12.1.2+20150906090309})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2+20150906090309-1 12.1.2+20150905090309-1})
    version_resolution_case('12.1.2+20150906090309-2', %w{12.1.2+20150906090309-1 12.1.2+20150906090309-2})
    version_resolution_case('12.1.2', %w{12.1.2 13.1.2})
    version_resolution_case('12.1.2', %w{12.1.2 12.2.2})
    version_resolution_case('12.1.2', %w{12.1.2 12.1.3})
  end

  context 'resolving with input 12.1.2-1' do
    let(:version) { '12.1.2-1' }

    version_resolution_case('12.1.2-1', %w{12.1.2-1 12.1.2-2 12.2.3})
  end

  context 'resolving with input 12.1.2+20150906090309' do
    let(:version) { '12.1.2+20150906090309' }

    version_resolution_case('12.1.2+20150906090309', %w{12.1.2-1 12.1.2+20150906090309})
    version_resolution_case('12.1.2+20150906090309', %w{12.1.2-1 12.1.2+20150906090309 12.1.2+20150906090309-1})
  end

  context 'resolving with input 12.1.2+20150906090309-1' do
    let(:version) { '12.1.2+20150906090309-1' }

    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2-1 12.1.2+20150906090309-1})
    version_resolution_case('12.1.2+20150906090309-1', %w{12.1.2-1 12.1.2+20150906090309 12.1.2+20150906090309-1})
  end
end
