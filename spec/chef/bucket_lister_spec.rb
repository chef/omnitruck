require 'spec_helper'

describe Chef::BucketLister do
  let(:lister) { described_class.new('test_bucket') }

  describe '#fetch' do
    before do
      allow(lister).to receive(:key_of)
      allow(lister).to receive(:etag_of)
      allow(lister).to receive(:last_modified_of)
    end

    context 'when all keys are fetched in one request' do
      it 'only fetches once' do
        expect(lister).to receive(:fetch_next).once.with('').and_return([ false, %w(key1) ])
        lister.fetch { |key, etag, last_modified| nil }
      end
    end

    context 'when the request is truncated 2 times' do
      it 'fetches three times' do
        allow(lister).to receive(:key_of).with('key3').and_return('marker3')
        allow(lister).to receive(:key_of).with('key6').and_return('marker6')

        expect(lister).to receive(:fetch_next).once.with('').and_return([ true, %w(key1 key2 key3) ])
        expect(lister).to receive(:fetch_next).once.with('marker3').and_return([ true, %w(key4 key5 key6) ])
        expect(lister).to receive(:fetch_next).once.with('marker6').and_return([ false, %w(key7 key8 key9) ])
        lister.fetch { |key, etag, last_modified| nil }
      end
    end

    it 'yields the items fetched' do
      allow(lister).to receive(:key_of).with('item1').and_return('key1')
      allow(lister).to receive(:key_of).with('item2').and_return('key2')
      allow(lister).to receive(:etag_of).with('item1').and_return('etag1')
      allow(lister).to receive(:etag_of).with('item2').and_return('etag2')
      allow(lister).to receive(:last_modified_of).with('item1').and_return('date1')
      allow(lister).to receive(:last_modified_of).with('item2').and_return('date2')
      allow(lister).to receive(:fetch_next).and_return([ false, %w(item1 item2) ])
      keys  = []
      etags = []
      dates = []
      lister.fetch do |key, etag, last_modified|
        keys << key
        etags << etag
        dates << last_modified
      end

      expect(keys).to eq(%w(key1 key2))
      expect(etags).to eq(%w(etag1 etag2))
      expect(dates).to eq(%w(date1 date2))
    end
  end

  describe '#last_modified_of' do
    let(:element)  { double('element') }
    let(:xpath)    { double('xpath') }
    let(:datetime) { double('datetime')}
    let(:time)     { double('time') }

    context 'when the last modified date is empty' do
      it 'returns nil' do
        allow(element).to receive(:xpath).and_return(xpath)
        allow(xpath).to receive(:text).and_return('')
        expect(lister.send(:last_modified_of, element)).to eq(nil)
      end
    end

    context 'when the last modified date is not empty' do
      it 'returns a time object' do
        allow(element).to receive(:xpath).and_return(xpath)
        allow(xpath).to receive(:text).and_return('2015-09-30T17:50:17.000Z')

        expect(DateTime).to receive(:rfc3339).with('2015-09-30T17:50:17.000Z').and_return(datetime)
        expect(datetime).to receive(:to_time).and_return(time)
        expect(lister.send(:last_modified_of, element)).to eq(time)
      end
    end
  end
end
