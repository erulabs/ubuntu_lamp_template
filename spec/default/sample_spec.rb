require_relative '../spec_helper'

describe package('apache2') do
  it { should be_installed }
end
describe service('apache2') do
  it { should be_enabled }
  it { should be_running }
end
describe port(8080) do
  it { should be_listening }
end

describe package('varnish') do
  it { should be_installed }
end
describe service('varnish') do
  it { should be_enabled }
  it { should be_running }
end
describe port(80) do
  it { should be_listening }
end
