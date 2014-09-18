# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:site_config' do
  def setup_mock_sites(sites)
    site_dir = File.join cookbook_path, 'templates', 'default', environment_name, 'sites'
    FileUtils.mkdir_p site_dir
    [*sites].each do |site_name|
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
    'bsw_nginx'
  end

  def lwrps_under_test
    'site_config'
  end

  def setup_recipe(sites, contents)
    setup_mock_sites sites
    temp_lwrp_recipe contents
  end

  def stub_existing_sites(sites, base_path='/etc/nginx')
    # dir will always include this
    complete = ['.', '..'] + sites
    Dir.stub(:entries).and_call_original
    Dir.stub(:entries).with(File.join(base_path, 'sites-enabled')).and_return complete
    avail = File.join(base_path, 'sites-available')
    Dir.stub(:entries).with(avail).and_return complete
    Dir.stub(:exists?).with(avail).and_return true
  end

  it 'creates a directory for sites-available and sites-enabled' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe [], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    @chef_run.should create_directory '/etc/nginx/sites-enabled'
    @chef_run.should create_directory '/etc/nginx/sites-available'
  end

  it 'works properly if no sites exist' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe [], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to be_empty
  end

  it 'works properly if all sites are removed' do
    # arrange
    stub_existing_sites ['site3', 'site4']

    # act
    setup_recipe [], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to be_empty
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site3')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site3')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site4')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site4')
    expect(resource.action).to eq [:delete]
  end

  it 'works properly with no variables and 1 site' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe 'site1.conf', <<-EOF
        bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name => 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
  end

  it 'works properly with variables and 1 site' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe 'site1.conf', <<-EOF
      bsw_nginx_site_config 'site config' do
        variables({:stuff => 'foobar'})
      end
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq(:stuff => 'foobar', :site_name => 'site1')
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
  end

  it 'works properly with multiple sites' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe ['site1.conf', 'site2.conf'], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name=> 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2.conf')
    expect(resource.variables).to eq({:site_name => 'site2'})
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2.conf')
  end

  it 'replaces sites that exist already' do
    # arrange
    stub_existing_sites ['site1.conf', 'site2.conf']

    # act
    setup_recipe ['site1.conf', 'site2.conf'], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(2).items
    # Only the template will be used, we're only using file to delete sites we don't need anymore
    expect(@chef_run.find_resources('file')).to have(0).items
    # Only the create links should be used
    expect(@chef_run.find_resources('link')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name=> 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2.conf')
    expect(resource.variables).to eq({:site_name=> 'site2'})
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2.conf')
  end

  it 'removes sites that are no longer configured' do
    # arrange
    stub_existing_sites ['site3.conf', 'site4.conf']

    # act
    setup_recipe ['site1.conf', 'site2.conf'], <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(2).items
    # Should have 1 file delete per each removed site
    expect(@chef_run.find_resources('file')).to have(2).items
    # should have 2 creates and 2 deletes
    expect(@chef_run.find_resources('link')).to have(4).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name=> 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2.conf')
    expect(resource.variables).to eq({:site_name=> 'site2'})
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2.conf')
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site3.conf')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site3.conf')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site4.conf')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site4.conf')
    expect(resource.action).to eq [:delete]
  end

  it 'works with a different base path' do
    # arrange
    stub_existing_sites [], '/etc/other_dir'

    # act
    setup_recipe 'site1.conf', <<-EOF
      bsw_nginx_site_config 'site config' do
        base_path '/etc/other_dir'
      end
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/other_dir/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name=> 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/other_dir/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/other_dir/sites-available/site1.conf')
    @chef_run.should create_directory '/etc/other_dir/sites-enabled'
    @chef_run.should create_directory '/etc/other_dir/sites-available'
  end

  it 'works properly when the sites directories do not exist' do
    # arrange
    Dir.stub(:entries).and_call_original
    base_path = '/etc/nginx'
    Dir.stub(:entries).with(File.join(base_path, 'sites-enabled')).and_raise 'directory does not exist'
    avail = File.join(base_path, 'sites-available')
    Dir.stub(:entries).with(avail).and_raise 'directory does not exist'
    Dir.stub(:exists?).with(avail).and_return false

    # act
    setup_recipe 'site1.conf', <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1.conf')
    expect(resource.variables).to eq({:site_name=> 'site1'})
    expect(resource.source).to eq 'thestagingenv/sites/site1.conf.erb'
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1.conf')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1.conf')
  end

  it 'suppresses output if told to do so' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe 'site1', <<-EOF
      bsw_nginx_site_config 'site config' do
        suppress_output true
      end
    EOF

    # assert
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    resource.sensitive.should == true
  end

  it 'does not suppress output by default' do
    # arrange
    stub_existing_sites []

    # act
    setup_recipe 'site1', <<-EOF
      bsw_nginx_site_config 'site config'
    EOF

    # assert
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    resource.sensitive.should == false
  end
end
