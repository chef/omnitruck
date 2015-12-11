require 'spec_helper'

describe Chef::ProjectCache do
  let(:project)       { double('project') }
  let(:project_cache) { described_class.new(project, 'metadata_dir') }

  describe '#fix_windows_manifest!' do
    # someone other than me that understands the intention of this method
    # should write the test for this. When fixing up a version, it looks like
    # like it just takes the last version parsed, even if there's multiple
    # architectures (i.e. a manifest could have a 12.5.1 in i386, i686 and
    # x86_64 - it doesn't seem to choose "the right one"). I don't want to
    # misinterpret the actual intention of this method.
  end

  describe '#update' do
    let(:file_handle) { double('file') }

    before do
      allow(project_cache).to receive(:update_cache)
      allow(project_cache).to receive(:generate_combined_manifest)
      allow(project_cache).to receive(:write_data)
      allow(project_cache).to receive(:build_list_path)
      allow(project_cache).to receive(:platform_names_path)
      allow(File).to receive(:open)
    end

    it 'updates the cache' do
      expect(project_cache).to receive(:update_cache)
      project_cache.update
    end

    it 'fixes the windows manifest if a remap version is provided' do
      expect(project_cache).to receive(:fix_windows_manifest!)
      project_cache.update('remap_version')
    end

    it 'writes out the build list' do
      allow(project_cache).to receive(:build_list_path).and_return('/path/to/build_list')
      allow(project_cache).to receive(:generate_combined_manifest).and_return('manifest_data')

      expect(project_cache).to receive(:write_data).with('/path/to/build_list', 'manifest_data')
      project_cache.update
    end

    it 'writes out the project names' do
      allow(project_cache).to receive(:platform_names_path).and_return('/path/to/platform_names')
      allow(project).to receive(:get_platform_names).and_return('platform_names')

      expect(File).to receive(:open).with('/path/to/platform_names', 'w').and_yield(file_handle)
      expect(file_handle).to receive(:puts).with('platform_names')
      project_cache.update
    end
  end

  describe '#name' do
    it 'returns the project name' do
      allow(project).to receive(:name).and_return('project_name')
      expect(project_cache.name).to eq('project_name')
    end
  end

  describe '#build_list_path' do
    it 'returns the path to the build list file' do
      allow(project_cache).to receive(:name).and_return('project_name')

      expect(project_cache).to receive(:metadata_file).with('build-project_name-list.json').and_return('full_path')
      expect(project_cache.build_list_path).to eq('full_path')
    end
  end

  describe '#platform_names_path' do
    it 'returns the path to the platform names file' do
      allow(project_cache).to receive(:name).and_return('project_name')

      expect(project_cache).to receive(:metadata_file).with('project_name-platform-names.json').and_return('full_path')
      expect(project_cache.platform_names_path).to eq('full_path')
    end
  end

  describe '.for_project' do
    it 'creates a project instance and returns a project cache instance' do
      expect(Chef::Project).to receive(:new).with('test_name', 'test_channel').and_return(project)
      expect(Chef::ProjectCache).to receive(:new).with(project, 'test_directory').and_return(project_cache)
      expect(Chef::ProjectCache.for_project('test_name', 'test_channel', 'test_directory')).to eq(project_cache)
    end
  end

  describe '#timestamp' do
    it 'returns the parsed timestamp' do
      allow(project_cache).to receive(:build_list_path).and_return('test_path')

      expect(File).to receive(:read).with('test_path').and_return('{"run_data": {"timestamp":"test_time"}}')
      expect(project_cache.timestamp).to eq('test_time')
    end
  end

  describe '#update_cache' do
    before do
      allow(project_cache).to receive(:debug)
      allow(project_cache).to receive(:create_cache_dirs)
      allow(project_cache).to receive(:manifests_to_fetch).and_return([])
      allow(project_cache).to receive(:local_manifests).and_return([])
      allow(project).to receive(:manifests).and_return([])
    end

    it 'deletes manifests that are no longer on s3' do
      allow(project_cache).to receive(:local_manifests).and_return(%w(man1 man2 man3 man4 man5))
      allow(project).to receive(:manifests).and_return(%w(man1 man2 man3))

      expect(project_cache).to receive(:delete_manifest).with('man4')
      expect(project_cache).to receive(:delete_manifest).with('man5')
      project_cache.send(:update_cache)
    end

    it 'fetches all necessary manifests' do
      allow(project_cache).to receive(:manifests_to_fetch).and_return(%w(man1 man2))

      expect(project_cache).to receive(:fetch_manifest).with('man1')
      expect(project_cache).to receive(:fetch_manifest).with('man2')
      project_cache.send(:update_cache)
    end
  end

  describe '#should_fetch_manifest?' do
    context 'when the local manifest does not exist' do
      it 'returns true' do
        allow(project_cache).to receive(:local_manifest_exists?).and_return(false)
        expect(project_cache.send(:should_fetch_manifest?, 'test')).to eq(true)
      end
    end

    context 'when local file exists but md5s are not available' do
      it 'falls back to mtime' do
        allow(project_cache).to receive(:local_manifest_exists?).and_return(true)
        allow(project_cache).to receive(:have_both_md5s_for?).and_return(false)

        expect(project_cache).to receive(:remote_manifest_newer?)
        project_cache.send(:should_fetch_manifest?, 'test')
      end
    end

    context 'when local file exists and md5s match' do
      it 'returns false' do
        allow(project_cache).to receive(:local_manifest_exists?).and_return(true)
        allow(project_cache).to receive(:have_both_md5s_for?).and_return(true)
        allow(project_cache).to receive(:manifest_md5_matches?).and_return(true)

        expect(project_cache.send(:should_fetch_manifest?, 'test')).to eq(false)
      end
    end

    context 'when local file exists and md5s do not match' do
      it 'returns true' do
        allow(project_cache).to receive(:local_manifest_exists?).and_return(true)
        allow(project_cache).to receive(:have_both_md5s_for?).and_return(true)
        allow(project_cache).to receive(:manifest_md5_matches?).and_return(false)

        expect(project_cache.send(:should_fetch_manifest?, 'test')).to eq(true)
      end
    end

    context 'when local file exists but md5s are not available' do
      it 'falls back to mtime and returns the value of remote_manifest_newer?' do
        allow(project_cache).to receive(:local_manifest_exists?).and_return(true)
        allow(project_cache).to receive(:have_both_md5s_for?).and_return(false)

        expect(project_cache).to receive(:remote_manifest_newer?).and_return(true)
        expect(project_cache.send(:should_fetch_manifest?, 'test')).to eq(true)
      end
    end
  end

  describe '#local_manifest_md5_for' do
    it 'returns nil if the file does not exist' do
      allow(project_cache).to receive(:local_manifest_exists?).and_return(false)
      expect(project_cache.send(:local_manifest_md5_for, 'test')).to eq(nil)
    end

    it 'returns the md5 of the file if it exists' do
      allow(project_cache).to receive(:local_manifest_exists?).and_return(true)
      allow(project_cache).to receive(:cache_path_for_manifest).and_return('full_path')

      expect(Digest::MD5).to receive(:file).with('full_path').and_return('md5here')
      expect(project_cache.send(:local_manifest_md5_for, 'test')).to eq('md5here')
    end
  end

  describe '#remote_manifest_newer?' do
    before do
      allow(project_cache).to receive(:local_manifest_mtime)
      allow(project).to receive(:manifest_last_modified_for)
    end

    context 'when local mtime is not available' do
      it 'returns true' do
        expect(project_cache.send(:remote_manifest_newer?, 'test')).to eq(true)
      end
    end

    context 'when remote mtime is not available' do
      it 'returns false' do
        allow(project_cache).to receive(:local_manifest_mtime).and_return(1)
        expect(project_cache.send(:remote_manifest_newer?, 'test')).to eq(false)
      end
    end

    context 'when both local and remote mtimes are available' do
      it 'returns the outcome of the comparison' do
        allow(project_cache).to receive(:local_manifest_mtime).and_return(1)
        allow(project).to receive(:manifest_last_modified_for).and_return(3)
        expect(project_cache.send(:remote_manifest_newer?, 'test')).to eq(true)
      end
    end
  end
end
