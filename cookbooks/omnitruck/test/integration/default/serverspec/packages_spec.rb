require 'spec_helper'

describe 'omnitruck instance packages' do
  describe package('ruby2.1') do
    it { should be_installed }
  end

  describe package('runit') do
    it { should be_installed }
  end
end
