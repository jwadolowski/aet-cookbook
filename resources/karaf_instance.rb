resource_name :karaf_instance

property :source, String
property :target, String

default_action :install

def url_filename(url)
  require 'uri'

  ::File.basename(URI.parse(url).path)
end

action :install do
  remote_file "#{Chef::Config[:file_cache_path]}/#{url_filename(source)}" do
    source new_resource.source

    action :create_if_missing
  end
end
