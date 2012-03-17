module GitGov
  class Repos
    class Seattle < GitGov::Repo

      def initialize( logger = GitGov.log )
        super
        @repo = Git.open(GitGov.repo_list['repo']['seattle'], :log => logger)
        @repo_path = GitGov.repo_list['repo']['seattle']

      end

      def save(path, contents)
        item_path = File.join(repo_path,path)
        item_directory = File.dirname(item_path)

        FileUtils.mkdir_p(item_directory) unless File.directory? item_directory

        item_handle = File.open(item_path,'w')
        item_handle.write(contents)
        item_handle.close
        #repo.add(path)

      end

      def last_item(type)
        case type
        when :bill
          sub_path = "bill"
          ext = ".md"
        else
          raise NotImplemented, "#{type} is not supported"
        end
        puts File.join(@repo_path,sub_path,"*")
        last_bucket = Dir[File.join(@repo_path,sub_path,"*")].map { |i| begin File.basename(i,ext).to_i end }.sort.last 
        puts last_bucket
        Dir[File.join(repo_path,sub_path,last_bucket.to_s,"*.md")].map { |i| File.basename(i,ext).to_i }.sort.last       
      end

    end
  end

end