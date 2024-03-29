require 'tempfile'
require 'nokogiri'
require 'tempfile'
require 'open-uri'
require 'json'

module GitGov
  
  class RepoException < RuntimeError
  end

  module Models
    class SeattleBill < GitGov::Models::RepoItem
      
      attr_reader :source_url

      def initialize(key)
        @key = key
        @type = :bill
        @source_url = "http://clerk.seattle.gov/~scripts/nph-brs.exe?d=ORDF&s1=#{@key}.cbn.&Sect6=HITOFF&l=20&p=1&u=/~public/cbory.htm&r=1&f=G"
        @repo = GitGov::Repos::Seattle.new(GitGov::repo_list['seattle'])

      end

      def markdown(source = nil)

        # If the user has not specified a source, set it tho the most efficient source
        if source.nil?
          if has_repo_copy?
            source = :local 
          else
            source = :remote
          end
        end

        if source.eql? :remote 
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

      def gfm(source = :remote)
        markdown(source).each_line.collect { |p| p.gsub( /(\\)?\n/, "  \n")}.join()
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

      def save(source = :remote)
        repo.save(location(:relative),gfm(source))
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
            rtn_headers[header] = proc.call(rtn_headers[header].chomp.lstrip.rstrip) if rtn_headers[header]
          rescue Exception => e
            GitGov.log.error "Exception: #{@key} - #{header}, #{e.class}, #{e.message} - '#{rtn_headers[header]}'"
            GitGov.log.error rtn_headers[header] if rtn_headers[header] 
          end
        end
        {:metadata => rtn_headers, :extra_fields => headers }

      end

      def save_metadata(overwrite = false)
        md = metadata_location(:repo)
        FileUtils.mkdir_p( File.dirname(md) ) unless File.directory? File.dirname(md)
        File.open(md, 'w') {|f| f.write(normalize_header[:metadata].to_json) }
      end

      private
      def is_hrule?(line)
        line.chomp.lstrip.rstrip.eql? "* * * * *"
      end

      def metadata_map
        { :bill_number => /^\*\*Council Bill Number: \[\]\(#h0\)\[\]\(#h2\)(?<h_val>\d+)\*\*/,
          :ordinance_number => /^\*\*Ordinance Number: (?<h_val>\d+)\*\*/,
          :status => /^\*\*Status:\*\* (?<h_val>\w+) \\/,
          :date_passed => /^\*\*Date passed by Full Council:\*\* (?<h_val>\w+ \d+, \d+) /,
          :date_filed => /^\*\*Date filed with the City Clerk:\*\* (?<h_val>\w+ \d+, \d+) /,
          :date_of_signature => /\*\*Date of Mayor's signature:\*\*((?<h_val>\s\w+ \d+, \d+)|(?<h_val>\s+))/,
          :date_introduced => /^\*\*Date introduced\/referred to committee:\*\* (?<h_val>\w+ \d+, \d+) /,
          :index_terms => /^\*\*Index Terms:\*\* (?<h_val>.*)/,
          :references => /^\*\*References\/Related Documents:\*\* (?<h_val>.*)/,
          :fiscal_note => /^\*\*Fiscal Note:\*\* (\*(?<h_val>.*)\*|(?<h_val>.*))/,
          :summary => /^(?<h_val>([a-zA-Z]|[0-9]).*)/,
          :committee => /^\*\*Committee:\*\*(?<h_val>.*) /,
          :sponsor => /^\*\*Sponsor:\*\*(?<h_val>.*) /,
          :vote => /^\*\*Vote:\*\* (?<h_val>.*) /,
          :electronic_copy => /^\*\*Electronic Copy: ?\*\* (?<h_val>.*)/,
          :note => /^\*\*Note:\*\* (?<h_val>.*)/,
          :status => /\*\*Status:\*\* ((?<h_val>.*) ?)/,
          :committee_vote => /^\*\*Committee Vote:\*\* (?<h_val>.*) (\\{1,2})?/,
          :committee_recommendation => /^\*\*Committee Recommendation:\*\* (?<h_val>.*) \\?/,
          :date_of_committee_recommendation => /^\*\*Date of Committee Recommendation:\*\* (?<h_val>.*) / 
        }
      end

      def metadata_transform
        { :bill_number => Proc.new { |i| i.to_i },
          :ordinance_number => Proc.new { |i| i.to_i },
          :status => Proc.new { |i| i.downcase.chomp.lstrip.rstrip },
          :date_passed => Proc.new { |i| DateTime.parse(i) },
          :date_filed => Proc.new { |i| DateTime.parse(i) },
          :date_of_signature => Proc.new { |i| (i.empty? or i.nil?) ? nil : DateTime.parse(i) },
          :date_introduced => Proc.new { |i| DateTime.parse(i) },
          :index_terms => Proc.new { |i| i.split(',').map { |t| t.split('-').collect{ |tm| tm.chomp.rstrip.lstrip }.join(" ") } },
          :fiscal_note => Proc.new { |i| i.eql?('(No fiscal note available at this time)') ? nil : i },
          :committee => Proc.new { |i| i.chomp.rstrip.lstrip },
          :sponsor => Proc.new { |i| i.chomp.rstrip.lstrip },
          :vote => Proc.new { |i| i.chomp.rstrip.lstrip },
          :electronic_copy => Proc.new { |i| i.chomp.rstrip.lstrip },
          :note => Proc.new { |i| i.chomp.rstrip.lstrip },
          :committee_vote => Proc.new { |i| i.chomp.rstrip.lstrip },
          :committee_recommendation => Proc.new { |i| i.downcase }, 
          :date_of_committee_recommendation => Proc.new { |i| DateTime.parse(i) },

        }
      end


      def bucket
        ((@key.to_i/1000).floor*1000).to_s
      end

      def metadata_location(type)
        case type

        when :relative
          File.join(@type.to_s,bucket, "#{@key}.json")
        when :repo
          File.join(repo.repo_path,metadata_location(:relative))
        else
          raise NotImplemented, "#{type} is not a valid location type"
        end
      end

      def location(type)

        case type

        when :relative
          File.join(@type.to_s,bucket,"#{@key}.md")
        when :repo
          File.join(repo.repo_path,location(:relative))
        else
          raise NotImplemented, "#{type} is not a valid location type"
        end
      end


    end
  end
end
