resource_name :karaf_instance

property :source_url, String
property :target, String

default_action :install

def url_filename(url)
  require 'uri'

  ::File.basename(URI.parse(url).path)
end

action :install do
  remote_file "#{Chef::Config[:file_cache_path]}/#{url_filename(source_url)}" do
    source source_url

    action :create_if_missing
  end
end
