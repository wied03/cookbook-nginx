# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:other_config' do
  include BswTech::ChefSpec::LwrpTestHelper

  before {
    stub_resources
  }

  after(:each) {
    cleanup
  }

  def cookbook_under_test
    'bsw_nginx'
  end

  def lwrps_under_test
    'other_config'
  end

  it 'works properly with no variables' do
    # arrange
    temp_lwrp_recipe <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_other_config '/etc/nginx.conf'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx.conf')
    expect(resource.variables).to eq({})
    expect(resource.source).to eq 'thestagingenv/nginx.conf.erb'
    resource = @chef_run.find_resource 'bsw_nginx_other_config', '/etc/nginx.conf'
    expect(resource.updated_by_last_action?).to be_true
  end

  it 'works properly with variables' do
    # arrange
    temp_lwrp_recipe <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_other_config '/etc/nginx.conf2' do
        variables({:stuff => 'foobar'})
      end
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx.conf2')
    expect(resource.variables).to eq(:stuff => 'foobar')
    expect(resource.source).to eq 'thestagingenv/nginx.conf2.erb'
    resource = @chef_run.find_resource 'bsw_nginx_other_config', '/etc/nginx.conf2'
    expect(resource.updated_by_last_action?).to be_true
  end

  it 'sets the updated flag if the template is updated' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'does not set the updated flag if the template is not updated' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'works with a different base path' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end
end
