# Encoding: utf-8

require_relative 'spec_helper'

describe 'naemon::lwrp:service' do
  include BswTech::ChefSpec::LwrpTestHelper

  before {
    stub_resources
  }

  after(:each) {
    cleanup
  }

  def cookbook_under_test
    'nginx'
  end

  def lwrps_under_test
    'site_config'
  end

  def setup_recipe(contents)
    temp_lwrp_recipe contents
  end

  it 'sets up the template to be done at the end of the chef run' do
    # assert
    temp_lwrp_recipe <<-EOF
        nginx_site_config 'site1'
    EOF

    # act + assert
    resource = @chef_run.find_resource('nginx_site_config', 'site1')
    expect(resource).to notify('nginx_site_config[apply]').to(:apply).delayed
  end

  it 'works properly with no variables and 1 site' do
    # arrange
    setup_recipe <<-EOF
        nginx_site_config 'site1'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    expect(resource).to notify('service[nginx]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
  end

  it 'works properly with variables and 1 site' do
    # arrange
    setup_recipe <<-EOF
            nginx_site_config 'site1' do
              variables({:stuff => 'foobar'})
            end
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq(:stuff => 'foobar')
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    expect(resource).to notify('service[nginx]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
  end

  it 'works properly with multiple sites' do
    # arrange
    setup_recipe <<-EOF
      nginx_site_config 'site1'
      nginx_site_config 'site2'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to be_nil
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2')
    expect(resource.variables).to be_nil
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    expect(@chef_run).to create_link('/etc/nginx/sites-enabled/site1').with(to: '/etc/nginx/sites-available/site1')
  end

  it 'replaces sites that exist already' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'removes sites that are no longer configured' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end
end
