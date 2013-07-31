require 'ruby_cop/gray_list'

module RubyCop
  describe GrayList do
    it 'allows items in the whitelist' do
      subject.whitelist('foo')
      subject.allow?('foo').should be_true
    end

    it 'allows rejects items in the whitelist' do
      subject.blacklist('foo')
      subject.allow?('foo').should be_false
    end

    it 'allows unknown things default' do
      subject.allow?('foo').should be_true
    end

    context 'when strict' do
      it 'does not allow unkowns' do
        subject.strict = true
        subject.allow?('foo').should be_false
      end
    end
  end
end
