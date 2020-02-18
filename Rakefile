# frozen_string_literal: true

require 'rake'
require 'bundler/gem_tasks'

task default: :rspec

desc "Run RSpec Unit Tests"
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:rspec) do |t|
    # t.rspec_opts = '--format documentation'
  end
end
