require 'nokogiri'
require 'open-uri'
require 'tempfile'
require 'fileutils'
require 'logger'
require 'git'


require 'git_gov/repo.rb'

require 'git_gov/repos/seattle'
require 'git_gov/models/repo_item'
require 'git_gov/models/seattle_bill'


module GitGov
  def self.log=(value)
    @@log
  end
  def self.log
    @@log ||= begin
      l = Logger.new(STDOUT)
      l.level = Logger::INFO
      l
    end 
  end

  def self.repo_list=(value)
    @@repo_list = value
  end

  def self.repo_list
    @@repo_list
  end
  
end
