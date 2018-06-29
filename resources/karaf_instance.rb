resource_name :karaf_instance

property :source, String, default: ''
property :target, String, default: ''
property :log_dir, String, default: ''
property :daemon_user, String, default: 'karaf'
property :daemon_group, String, default: 'karaf'
property :login, String, default: 'karaf'
property :password, String, default: 'karaf'

default_action :install

def url_filename(url)
  require 'uri'

  ::File.basename(URI.parse(url).path)
end

def distribution_tmp_path
  "#{Chef::Config[:file_cache_path]}/#{url_filename(source)}"
end

def identical_user_and_group?(resource)
  resource.daemon_user == resource.daemon_group
end

def validate_properties(resource)
  # Make sure crucial properties have been set
  %w(source target log_dir).each do |property|
    Chef::Application.fatal!(
      "#{property} property can't be empty!"
    ) if resource.send(property.to_sym).empty?
  end

  # Windows specific constraints
  Chef::Application.fatal!(
    "Windows doesn't allow users and groups with the same name!"
  ) if platform_family?('windows') && identical_user_and_group?(resource)
end

action :install do
  validate_properties(new_resource)

  # ---------------------------------------------------------------------------
  # Daemon user & group
  # ---------------------------------------------------------------------------
  user new_resource.daemon_user do
    system true
    shell '/bin/bash' unless platform_family?('windows')

    action :create
  end

  group new_resource.daemon_group do
    members [new_resource.daemon_user]
  end

  # ---------------------------------------------------------------------------
  # Karaf home and log directories
  # ---------------------------------------------------------------------------
  directory new_resource.target do
    owner new_resource.daemon_user
    group new_resource.daemon_group
    mode '0755'
    recursive true

    action :create
  end

  directory new_resource.log_dir do
    owner new_resource.daemon_user
    group new_resource.daemon_group
    mode '0755'
    recursive true

    action :create
  end

  # ---------------------------------------------------------------------------
  # Download and unpack Apache Karaf distribution
  # ---------------------------------------------------------------------------
  remote_file distribution_tmp_path do
    source new_resource.source

    action :create_if_missing
  end

  if platform_family?('windows')
    windows_zipfile new_resource.target do
      source distribution_tmp_path

      action :unzip
    end
  else
    # TODO: add unzip for linux
  end
end
