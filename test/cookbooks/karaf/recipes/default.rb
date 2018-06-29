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

  action :install
end
