require 'spec_helper'

describe 'omnitruck instance users' do
  describe user('omnitruck') do
    it { should exist }
    it { should belong_to_group 'omnitruck' }
    it { should have_home_directory '/srv/omnitruck' }
    it { should have_login_shell '/bin/false' }
  end

  [
    '/srv/omnitruck',
    '/srv/omnitruck/shared',
    '/srv/omnitruck/shared/pids',
  ].each do |f|
    describe file(f) do
      it { should be_owned_by 'omnitruck' }
      it { should be_grouped_into 'omnitruck' }
    end
  end
end
