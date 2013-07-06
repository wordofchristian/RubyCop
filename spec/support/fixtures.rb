module Fixtures
  def fixture(fixture_name)
    path = "#{File.dirname(__FILE__)}/../fixtures/#{fixture_name}.rb"
    File.read(path)
  end
end


RSpec.configure do |c|
  c.include Fixtures
end
