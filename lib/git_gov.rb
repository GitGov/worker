require 'nokogiri'
require 'open-uri'
require 'tempfile'
require 'fileutils'
require 'logger'
require 'git'

require 'git_gov/models/repo_item'
require 'git_gov/models/seattle_bill'

require 'git_gov/repo.rb'

module GitGov
  def log
    @@logger ||= begin
      l = Logger.new(STDOUT)
      l.level = Logger::INFO
      l
    end 
  end
  def log=(logger)
    @@logger = logger
  end
end
