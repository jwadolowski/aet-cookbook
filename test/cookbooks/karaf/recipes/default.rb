karaf_instance 'main' do
  source 'https://archive.apache.org/dist/karaf/4.2.0/apache-karaf-4.2.0.tar.gz'
  target '/opt/karaf'

  action :install
end
