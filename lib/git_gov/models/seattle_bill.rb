require 'tempfile'
require 'nokogiri'
require 'tempfile'
require 'open-uri'

module GitGov
  
  class RepoException < RuntimeError
  end

  module Models
    class SeattleBill < GitGov::Models::RepoItem
      
      attr_reader :source_url

      def initialize(key, repo )
        @key = key
        @type = :bill
        @source_url = "http://clerk.seattle.gov/~scripts/nph-brs.exe?d=ORDF&s1=#{@key}.cbn.&Sect6=HITOFF&l=20&p=1&u=/~public/cbory.htm&r=1&f=G"
        @repo = repo

      end

      def markdown(source = nil)

        # If the user has not specified a source, set it tho the most efficient source
        source = source.nil? and has_repo_copy? ? :local : :remote

        if source.eql? :remote or has_repo_copy? != true
          doc = get_doc

          content = doc.xpath("//*[@id='content_results']")
          content.children[-1].remove
          content.children[0].remove
          content.children[0].remove
          content.children[0].remove
          content.children[0].remove
          content.children[0].remove

          raw_file = Tempfile.new('bill-raw')
          raw_file.write(content.to_s.encode("UTF-8"))
          raw_file.close

          markdown = `cat #{raw_file.path} | pandoc -t markdown -f html --no-wrap`
          raise DocumentConversionException, "Failed to execute pandoc #{pd_result}" unless $?.success?
        else
          markdown = File.read(location(:repo))
        end

        markdown

      end

      def html
        if has_repo_copy?
          html = `cat #{location(:repo)} | pandoc -t html -f markdown `
          raise DocumentConversionException, "Failed to execute pandoc #{$?}" unless $?.success?  
        else
          raise GitGov::RepoException, "You must have a copy of this bill in your repo"
        end
        html
      end

      def save
        repo.save(location(:relative),markdown)
      end

      def is_bill?
        get_doc.xpath("//*[@id='content_results']/title").children[0].to_s != "Sorry"
      end

      def has_repo_copy?
        File.exists? location(:repo)
      end

      def get_doc
        @doc ||= Nokogiri::HTML(open(source_url))
      end

      def metadata
        headers = normalize_header()
        headers[:metadata]
      end

      def select_header
        header = []
        header_start = false
        header_mid = false
        header_end = false
        markdown.each_line do | line |
          
          
          header_end = true if is_hrule?(line) and header_mid.eql? true
          header_mid = true if is_hrule?(line) and header_start.eql? true
          return header if header_end


          header_start = true if is_hrule?(line) and header_start.eql? false

          header << line if line.chomp.empty? != true and header_start and header_end != true and is_hrule?(line) != true and line.chomp.eql?("\\") != true


        end
      end

      def normalize_header()
        headers = select_header
        return {:headers => nil, :extra_fields => nil} if headers.is_a? String
        rtn_headers = {}
        metadata_map.each do |key, value|
          line_number = 0
          taken_headers = []
          headers.each do |line|
            if value =~ line
              if rtn_headers[key]
                rtn_headers[key] += rtn_headers[key] + value.match(line)[:h_val]
              else
                rtn_headers[key] = value.match(line)[:h_val]
              end
              taken_headers << line_number
            end
            line_number += 1
          end
          taken_headers.each { | h | headers.delete_at(h) }
        end

        metadata_transform.each do |header, proc|
          GitGov.log.debug "Transform: #{header} => '#{rtn_headers[header]}'" if rtn_headers[header]
          begin
            rtn_headers[header] = proc.call(rtn_headers[header]) if rtn_headers[header]
          rescue Exception => e
            GitGov.log.error "Exception: #{header}, #{e.class}, #{e.message}"
            GitGov.log.error rtn_headers[header] if rtn_headers[header] 
          end
        end
        {:metadata => rtn_headers, :extra_fields => headers }

      end

      private
      def is_hrule?(line)
        line.chomp.eql? "* * * * *"
      end

      def metadata_map
        { :bill_number => /^\*\*Council Bill Number: \[\]\(#h0\)\[\]\(#h2\)(?<h_val>\d+)\*\*/,
          :ordinance_number => /^\*\*Ordinance Number: (?<h_val>\d+)\*\*/,
          :status => /^\*\*Status:\*\* (?<h_val>\w+) \\/,
          :date_passed => /^\*\*Date passed by Full Council:\*\* (?<h_val>\w+ \d+, \d+) \\/,
          :date_filed => /^\*\*Date filed with the City Clerk:\*\* (?<h_val>\w+ \d+, \d+) \\/,
          :date_of_signature => /\*\*Date of Mayor's signature:\*\*((?<h_val>\s\w+ \d+, \d+)|(?<h_val>\s+))/,
          :date_introduced => /^\*\*Date introduced\/referred to committee:\*\* (?<h_val>\w+ \d+, \d+) \\/,
          :index_terms => /^\*\*Index Terms:\*\* (?<h_val>.*)/,
          :references => /^\*\*References\/Related Documents:\*\* (?<h_val>.*)/,
          :fiscal_note => /^\*\*Fiscal Note:\*\* (\*(?<h_val>.*)\*|(?<h_val>.*))/,
          :summary => /^(?<h_val>([a-zA-Z]|[0-9]).*)/,
          :committee => /^\*\*Committee:\*\*(?<h_val>.*) \\/,
          :sponsor => /^\*\*Sponsor:\*\*(?<h_val>.*) \\/,
          :vote => /^\*\*Vote:\*\* (?<h_val>.*) \\/,
          :electronic_copy => /^\*\*Electronic Copy:\*\* (?<h_val>.*)/,
          :note => /^\*\*Note:\*\* (?<h_val>.*)/,
          :status => /\*\*Status:\*\* ((?<h_val>.*))/,
          :committee_vote => /^\*\*Committee Vote:\*\* (?<h_val>.*) \\?/,
          :committee_recommendation => /^\*\*Committee Recommendation:\*\* (?<h_val>.*) \\?/,
          :date_of_committee_recommendation => /^\*\*Date of Committee Recommendation:\*\* (?<h_val>.*) \\?/ 
        }
      end

      def metadata_transform
        { :bill_number => Proc.new { |i| i.to_i },
          :ordinance_number => Proc.new { |i| i.to_i },
          :status => Proc.new { |i| i.downcase },
          :date_passed => Proc.new { |i| DateTime.parse(i) },
          :date_filed => Proc.new { |i| DateTime.parse(i) },
          :date_of_signature => Proc.new { |i| DateTime.parse(i) },
          :date_introduced => Proc.new { |i| DateTime.parse(i) },
          :index_terms => Proc.new { |i| i.split(',').map { |t| t.split('-').join(" ") } },
          :fiscal_note => Proc.new { |i| i.eql?('(No fiscal note available at this time)') ? nil : i },
          :date_of_committee_recommendation => Proc.new { |i| DateTime.parse(i) },
          :committee_recommendation => Proc.new { |i| i.downcase }, 

        }
      end


    end
  end
end
