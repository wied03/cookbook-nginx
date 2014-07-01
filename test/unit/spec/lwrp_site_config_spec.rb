# Encoding: utf-8

require_relative 'spec_helper'

describe 'naemon::lwrp:service' do
  def setup_mock_sites(sites)
    [*sites].each do |site_name|
      site_dir = File.join cookbook_path, 'templates', 'default', environment_name, 'sites'
      FileUtils.mkdir_p site_dir
      site_filename = File.join site_dir, "#{site_name}.erb"
      FileUtils.touch site_filename
    end
  end

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

  def setup_recipe(sites,contents)
    setup_mock_sites sites
    temp_lwrp_recipe contents
  end

  it 'works properly with no variables and 1 site' do
    # arrange
    setup_recipe 'site1', <<-EOF
        nginx_site_config 'site config'
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
    setup_recipe 'site1', <<-EOF
            nginx_site_config 'site config' do
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
    setup_recipe ['site1','site2'], <<-EOF
      nginx_site_config 'site config'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    expect(resource).to notify('service[nginx]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2')
    expect(resource.variables).to eq({})
    expect(resource).to notify('service[nginx]').to(:configtest).delayed
    expect(resource).to notify('service[nginx]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2')
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
