require 'rubygems'
require 'bundler'
Bundler.setup

path = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH << path

require 'git_gov'

require 'yaml'

config_paths = ["~/.gitgov/config.yaml", "./config.yaml"].each do |p|
  p_e = File.expand_path(p)
  if File.exists? p_e
    puts p_e
    GitGov.repo_list = YAML.load(File.read(p_e))
  end
end

unless GitGov.repo_list 
  raise "Failed to load configuration file"
end


puts  GitGov.repo_list







REPO_BASE = File.expand_path("~/source/GitSeattle")

task :environment do
  LOG = Logger.new(STDOUT)

end

import 'tasks/get.rake'