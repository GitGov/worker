


class BillNotFoundException < RuntimeError

end

class DocumentConversionException < RuntimeError

end

include GitGov

namespace :seattle do
	namespace :bill do

		desc "Pull a bill from the accessors office"
		task :pull, [:bill] => :environment do |task, args|
			repo = GitGov::Repo.new(REPO_BASE)
			bill = GitGov::Models::SeattleBill.new(args[:bill],repo)
			bill.save
		end

		desc "Update the bill repo"
		task :update, [] => :environment do |task, args|
			log.info("Opening repository at #{REPO_BASE}")
			repo = GitGov::Repo.new(REPO_BASE)
			current_bill = (repo.last_item :bill) + 1
			log.info("Current bill is #{current_bill}")
			try_count = 0
			while true
				bill = GitGov::Models::SeattleBill.new(current_bill,repo)
				if bill.is_bill?
					try_count = 0
					log.info("#{current_bill} is a valid bill")
					bill.save
				else
					try_count += 1
					if try_count > 100
						log.info("#{current_bill-1} was the last bill for download")
						break
					end
				end
				current_bill += 1	
			end
		end

		desc "Test HTML"
		task :html, [] => :environment do |task, args| 
			repo = GitGov::Repo.new(REPO_BASE)
			Dir["#{REPO_BASE}/bill/*.md"].each do |file|
				GitGov.log.info "Extracting Metadata for #{file}"
				bill_number = File.basename(file,'.md')
				bill = GitGov::Models::SeattleBill.new(bill_number,repo)
				if bill.normalize_header[:extra_fields]
					bill.normalize_header[:extra_fields].each do |field|

						case field
						when /\*\(.*\)\*/
						when /\[\(.*\)\]\(.*\)/
						else 
							GitGov.log.warn "Extra Info: #{field.inspect}"
							puts field
						end
					end
				end
			end
	
		end

	end
end

