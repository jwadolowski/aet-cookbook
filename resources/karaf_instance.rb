resource_name :karaf_instance

property :source, String, default: ''
property :target, String, default: ''
property :log_dir, String, default: ''
property :daemon_user, String, default: 'karaf'
property :daemon_group, String, default: 'karaf'
property :login, String, default: 'karaf'
property :password, String, default: 'karaf'

default_action :install

def filename(url)
  require 'uri'

  ::File.basename(URI.parse(url).path)
end

def filename_basename(filename)
  filename[/(.+)\.(tar\.gz|zip)$/, 1]
end

def home_dir
  ::File.join(
    target,
    filename_basename(filename(source))
  )
end

def distribution_tmp_path
  "#{Chef::Config[:file_cache_path]}/#{filename(source)}"
end

def validate_properties(resource)
  # Make sure crucial properties have been set
  %w(source target log_dir).each do |property|
    Chef::Application.fatal!(
      "#{property} property can't be empty!"
    ) if resource.send(property.to_sym).empty?
  end
end

action :install do
  validate_properties(new_resource)

  # ---------------------------------------------------------------------------
  # Daemon user & group
  #
  # There's no point to create dedicated service user/group on Windows
  # ---------------------------------------------------------------------------
  if platform_family?('rhel')
    group new_resource.daemon_group do
      action :create
    end

    user new_resource.daemon_user do
      system true
      group new_resource.daemon_group
      shell '/bin/bash'

      action :create
    end
  end

  # ---------------------------------------------------------------------------
  # Karaf home and log directories
  # ---------------------------------------------------------------------------
  directory new_resource.target do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0755'
    end
    recursive true

    action :create
  end

  directory new_resource.log_dir do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0755'
    end
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

      not_if { ::File.exist?(::File.join(home_dir, 'bin', 'karaf')) }
    end
  else
    # TODO: add unzip for linux
  end
end
