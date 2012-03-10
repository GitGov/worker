require 'rubygems'
require 'bundler'
Bundler.setup


 path = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH << path

require 'git_gov'

REPO_BASE = File.expand_path("../GitSeattle2")

task :environment do
  LOG = Logger.new(STDOUT)

end

import 'tasks/get.rake'