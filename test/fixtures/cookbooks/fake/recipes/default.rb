package 'nginx' do
  source '/vagrant/nginx-1.6.1-0.1.bsw.rhel.x86_64.rpm'
end

directory '/var/www/my_app/current/public' do
  recursive true
end

file '/var/www/my_app/current/public/index.html' do
  content 'hello world from bsw'
end

bsw_nginx_complete_config 'the config'

service 'nginx' do
  action [:enable, :start]
end