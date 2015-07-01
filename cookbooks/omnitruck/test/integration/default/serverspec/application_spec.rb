require 'spec_helper'

describe 'omnitruck web application' do
  describe port(4880) do
    it { should be_listening }
  end
end
