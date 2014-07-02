# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::default' do
  before { stub_resources }
  it 'defines a service resource correctly' do
    # arrange
    @chef_run = ChefSpec::Runner.new

    # act
    @chef_run.converge('bsw_nginx::default')

    # assert
    resource = @chef_run.find_resource 'service', 'nginx config reload'
    expect(resource).to_not be_nil
    expect(resource.service_name).to eq 'nginx'
    expect(resource.action).to eq [:nothing]
    expect(resource.supports).to eq :reload => true
    expect(resource.only_if.map { |c| c.command }).to eq ['service nginx status']
  end

  it 'defines a config test resource correctly' do
    # arrange
    @chef_run = ChefSpec::Runner.new

    # act
    @chef_run.converge('bsw_nginx::default')

    # assert
    resource = @chef_run.find_resource 'bash', 'nginx config test'
    expect(resource).to_not be_nil
    expect(resource.code).to eq '/usr/sbin/nginx -t'
    expect(resource.action).to eq [:nothing]
  end
end
