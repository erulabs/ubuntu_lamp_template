require_relative 'spec_helper'

[80, 8080, 11_211, 6082, 3306].each do |port|
  describe port(port) do
    it { should be_listening }
  end
end

services = %w( apache2 memcached varnish mysql )

services.each do |service|
  describe service(service) do
    it { should be_enabled }
    it { should be_running }
  end
end
