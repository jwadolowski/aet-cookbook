karaf_instance 'main' do
  source_url 'https://archive.apache.org/dist/karaf/4.2.0/apache-karaf-4.2.0.tar.gz'
  target '/opt/karaf'

  action :install
end
