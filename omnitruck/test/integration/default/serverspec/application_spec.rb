require 'spec_helper'

describe 'omnitruck web application' do
  describe port(80) do
    it { should be_listening }
  end
end
