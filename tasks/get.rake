require 'json'

class BillNotFoundException < RuntimeError

end

class DocumentConversionException < RuntimeError

end

include GitGov

namespace :seattle do
	namespace :bill do

		desc "Pull a bill from the accessors office"
		task :pull, [:bill] => :environment do |task, args|
			bill = GitGov::Models::SeattleBill.new(args[:bill])
			bill.save
		end

		desc "Update the bill repo"
		task :update, [] => :environment do |task, args|
			GitGov::log.info("Opening repository at #{REPO_BASE}")
			repo = GitGov::Repos::Seattle.new()
			current_bill = (repo.last_item :bill) + 1
			GitGov::log.info("Current bill is #{current_bill}")
			try_count = 0
			while true
				bill = GitGov::Models::SeattleBill.new(current_bill)
				if bill.is_bill?
					try_count = 0
					GitGov::log.info("#{current_bill} is a valid bill")
					bill.save
				else
					try_count += 1
					if try_count > 100
						GitGov::log.info("#{current_bill-1} was the last bill for download")
						break
					end
				end
				current_bill += 1	
			end
		end

		desc "Extract Metadata"
		task :metadata, [] => :environment do |task, args| 
			repo = GitGov::Repos::Seattle.new
			Dir["#{GitGov.repo_list['repo']['seattle']}/bill/*"].each do |dir|
				if File.directory? dir
					Dir["#{dir}/*.md"].each do |file|
			  		GitGov::log.info "Extracting Metadata for #{file}"
						bill_number = File.basename(file,'.md')

						bill = GitGov::Models::SeattleBill.new(bill_number)
						bill.save_metadata
					end
				end
			end
	
		end

		desc "Convert"
		task :convert, [] => :environment do |task, args|

			Dir["#{GitGov.repo_list['repo']['seattle']}/bill/*"].each do |dir|
				if File.directory? dir
					Dir["#{dir}/*.md"].each do |file|
						GitGov::log.info "Converting to GFM #{file}"
						bill_number = File.basename(file,'.md')
						bill = GitGov::Models::SeattleBill.new(bill_number)
						bill.save(:local)
					end
				end
			end
		end

		desc "Generate Document Index"
		task :doc_index, [] => :environment do |taks, args|
			index = []
			Dir["#{GitGov.repo_list['repo']['seattle']}/bill/*"].each do |dir|
				if File.directory? dir
					Dir["#{dir}/metadata/*.json"].each do |file|
						begin 
							bill_metadata = JSON.parse(File.read(file))
							document = {}
							document[:status] = bill_metadata['status']
							document[:text] = File.join( File.dirname(File.dirname(file)), "#{File.basename(file,'.json')}.md")
							index[bill_metadata['bill_number']] = document
						rescue Exception => e
							puts "Exception: #{file} #{e.message}"
						end
					end
				end
			end
			puts index

		end

	end

end

