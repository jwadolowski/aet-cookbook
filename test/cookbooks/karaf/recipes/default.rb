# https://github.com/sous-chefs/java/issues/391
if platform_family?('windows')
  include_recipe 'java::windows'
else
  include_recipe 'java'
end

karaf_instance 'main' do
  source node['aet']['karaf']['source']
  target node['aet']['karaf']['root_dir']
  log_dir node['aet']['karaf']['log_dir']
  daemon_user node['aet']['karaf']['user']
  daemon_group node['aet']['karaf']['group']
  login node['aet']['karaf']['login']
  password node['aet']['karaf']['password']
  jvm_min_heap node['aet']['karaf']['java_min_mem']
  jvm_max_heap node['aet']['karaf']['java_max_mem']
  jvm_perm_mem node['aet']['karaf']['java_min_perm_mem']
  jvm_max_perm_mem node['aet']['karaf']['java_max_perm_mem']
  web_port node['aet']['karaf']['web_port']
  ssh_port node['aet']['karaf']['ssh_port']

  action :install
end
