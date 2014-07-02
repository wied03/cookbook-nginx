# Encoding: utf-8
#
# Cookbook Name:: nginx
# Recipe:: default
#
# Copyright 2014, BSW Technology Consulting LLC
#
service 'nginx config reload' do
  service_name 'nginx'
  supports :reload => true
  action :nothing
  only_if 'service nginx status'
end

bash 'nginx config test' do
  code '/usr/sbin/nginx -t'
  action :nothing
end