# Encoding: utf-8

require_relative 'spec_helper'

describe command('curl -s http://localhost') do
  it { should return_stdout 'hello world from bsw' }
end
