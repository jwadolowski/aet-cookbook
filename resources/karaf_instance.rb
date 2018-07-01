resource_name :karaf_instance

property :source, String, default: ''
property :target, String, default: ''
property :log_dir, String, default: ''
property :daemon_user, String, default: 'karaf'
property :daemon_group, String, default: 'karaf'
property :login, String, default: 'karaf'
property :password, String, default: 'karaf'
property :jvm_min_heap, String, default: '512M'
property :jvm_max_heap, String, default: '1024M'
property :jvm_perm_mem, String, default: '64M'
property :jvm_max_perm_mem, String, default: '128M'
property :web_port, String, default: '8181'
property :ssh_port, String, default: '8101'

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

def home_dir_symlink
  ::File.join(target, 'current')
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

  link home_dir_symlink do
    to home_dir

    # TODO: does it suppose to restart Apache Karaf?
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

  # ---------------------------------------------------------------------------
  # Configuration files
  # ---------------------------------------------------------------------------
  template ::File.join(home_dir_symlink, 'bin', 'setenv') do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0644'
    end
    source 'content/karaf/current/bin/setenv.erb'
    cookbook node['aet']['karaf']['src_cookbook']['setenv']
    variables(
      min_heap: new_resource.jvm_min_heap,
      max_heap: new_resource.jvm_max_heap,
      perm_mem: new_resource.jvm_perm_mem,
      max_perm_mem: new_resource.jvm_max_perm_mem
    )

    # TODO: schedule delayed service restart
  end

  template ::File.join(home_dir_symlink, 'etc', 'users.properties') do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0644'
    end
    source 'content/karaf/current/etc/users.properties.erb'
    cookbook node['aet']['karaf']['src_cookbook']['users_prop']
    variables(
      login: new_resource.login,
      password: new_resource.password
    )

    # TODO: schedule delayed service restart
  end

  template ::File.join(home_dir_symlink, 'etc', 'org.ops4j.pax.web.cfg') do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0644'
    end
    source 'content/karaf/current/etc/org.ops4j.pax.web.cfg.erb'
    cookbook node['aet']['karaf']['src_cookbook']['ops4j_cfg']
    variables(
      port: new_resource.web_port
    )

    # TODO: schedule delayed service restart
  end

  template ::File.join(home_dir_symlink, 'etc', 'org.apache.karaf.shell.cfg') do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0644'
    end
    source 'content/karaf/current/etc/org.apache.karaf.shell.cfg.erb'
    cookbook node['aet']['karaf']['src_cookbook']['shell_cfg']
    variables(
      port: new_resource.ssh_port
    )

    # TODO: schedule delayed service restart
  end

  # ---------------------------------------------------------------------------
  # Log directories
  # ---------------------------------------------------------------------------
  # Create data folder if it doesn't exists so that we can create link for logs
  directory ::File.join(home_dir_symlink, 'data') do
    if node['platform_family'] == 'rhel'
      owner new_resource.daemon_user
      group new_resource.daemon_group
      mode '0755'
    end
    recursive true

    action :create
  end

  directory ::File.join(home_dir_symlink, 'data', 'log') do
    action :delete

    not_if { ::File.symlink?(::File.join(home_dir_symlink, 'data', 'log')) }
  end

  link ::File.join(home_dir_symlink, 'data', 'log') do
    to new_resource.log_dir
  end

  # ---------------------------------------------------------------------------
  # Service
  # ---------------------------------------------------------------------------
  case node['platform_family']
  when 'windows'
    # TODO: windows
  when 'rhel'
    case node['platform_version'].to_i
    when 6
      # TODO: init.d
    when 7
      template '/etc/systemd/system/karaf.service' do
        owner 'root'
        group 'root'
        mode '0755'
        source 'etc/systemd/system/karaf.service.erb'
        cookbook node['aet']['karaf']['src_cookbook']['systemd_script']
        variables(
          home_dir: home_dir_symlink,
          user: new_resource.daemon_user,
          group: new_resource.daemon_group
        )

        notifies :run, 'execute[systemd-verify-karaf]', :immediately
        notifies :run, 'execute[systemd-reload]', :immediately
        notifies :restart, 'service[karaf]', :delayed
      end

      execute 'systemd-verify-karaf' do
        command 'systemd-analyze verify karaf.service'

        action :nothing
      end

      execute 'systemd-reload' do
        command 'systemctl daemon-reload'

        action :nothing
      end
    end
  end

  service 'karaf' do
    supports status: true, restart: true

    action [:start, :enable]
  end
end
