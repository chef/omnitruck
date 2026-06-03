#--
# Copyright:: Copyright (c) 2016-2024 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Chef::Cache do
  subject(:cache) { described_class.new }

  # ---------------------------------------------------------------------------
  # KNOWN_PROJECTS and KNOWN_CHANNELS constants
  # ---------------------------------------------------------------------------

  describe '::KNOWN_PROJECTS' do
    it 'is a non-empty array' do
      expect(described_class::KNOWN_PROJECTS).to be_an(Array)
      expect(described_class::KNOWN_PROJECTS).not_to be_empty
    end

    it 'includes core Chef products' do
      expect(described_class::KNOWN_PROJECTS).to include('chef', 'chef-workstation', 'chefdk', 'inspec')
    end
  end

  describe '::KNOWN_CHANNELS' do
    it 'includes stable, current and unstable' do
      expect(described_class::KNOWN_CHANNELS).to contain_exactly('current', 'stable', 'unstable')
    end
  end

  # ---------------------------------------------------------------------------
  # manifest_for
  # ---------------------------------------------------------------------------

  describe '#manifest_for' do
    context 'with a valid project and channel (stable/chef)' do
      it 'returns a parsed JSON hash' do
        result = cache.manifest_for('chef', 'stable')
        expect(result).to be_a(Hash)
      end

      it 'contains platform top-level keys' do
        result = cache.manifest_for('chef', 'stable')
        expect(result.keys).to include('el', 'ubuntu', 'debian')
      end

      it 'contains run_data with a timestamp' do
        result = cache.manifest_for('chef', 'stable')
        expect(result['run_data']).to be_a(Hash)
        expect(result['run_data']['timestamp']).to eq('2024-09-14 06:26:34 -0400')
      end

      it 'contains nested platform/version/arch/version_str package info' do
        result = cache.manifest_for('chef', 'stable')
        el7_x86 = result.dig('el', '7', 'x86_64')
        expect(el7_x86).to be_a(Hash)
        expect(el7_x86).not_to be_empty
        # Each version entry has sha1, sha256, url
        version_entry = el7_x86.values.first
        expect(version_entry).to have_key('sha1')
        expect(version_entry).to have_key('sha256')
        expect(version_entry).to have_key('url')
      end
    end

    context 'with a valid project and channel (current/chef)' do
      it 'returns a parsed JSON hash for the current channel' do
        result = cache.manifest_for('chef', 'current')
        expect(result).to be_a(Hash)
        expect(result.keys).to include('el')
      end

      it 'contains run_data with the current channel timestamp' do
        result = cache.manifest_for('chef', 'current')
        expect(result['run_data']['timestamp']).to eq('2024-09-14 08:01:51 -0400')
      end
    end

    context 'with a valid project and channel (stable/chefdk)' do
      it 'returns a non-empty hash for chefdk' do
        result = cache.manifest_for('chefdk', 'stable')
        expect(result).to be_a(Hash)
        expect(result).not_to be_empty
      end
    end

    context 'with a project that has no fixture file' do
      # MockRedis returns nil when the file does not exist, which causes
      # manifest_for to raise MissingManifestFile.
      it 'raises MissingManifestFile' do
        expect {
          cache.manifest_for('nonexistent-project-xyz', 'stable')
        }.to raise_error(Chef::Cache::MissingManifestFile)
      end

      it 'includes the project and channel in the error message' do
        expect {
          cache.manifest_for('nonexistent-project-xyz', 'stable')
        }.to raise_error(Chef::Cache::MissingManifestFile, /nonexistent-project-xyz.*stable/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # last_modified_for
  # ---------------------------------------------------------------------------

  describe '#last_modified_for' do
    context 'with a valid project and channel (stable/chef)' do
      it 'returns the timestamp string from run_data' do
        result = cache.last_modified_for('chef', 'stable')
        expect(result).to eq('2024-09-14 06:26:34 -0400')
      end
    end

    context 'with a valid project and channel (current/chef)' do
      it 'returns the correct timestamp for the current channel' do
        result = cache.last_modified_for('chef', 'current')
        expect(result).to eq('2024-09-14 08:01:51 -0400')
      end
    end

    context 'with a project that has no fixture file' do
      it 'raises MissingManifestFile' do
        expect {
          cache.last_modified_for('nonexistent-project-xyz', 'stable')
        }.to raise_error(Chef::Cache::MissingManifestFile)
      end
    end
  end
end
