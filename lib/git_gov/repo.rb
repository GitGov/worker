module GitGov
  class Repo
    
    attr_reader :logger
    attr_reader :repo
    attr_reader :repo_path

    def initialize( repo_dir, logger = GitGov.log )
    
      @repo = Git.open(repo_dir, :log => logger)
      @repo_path = repo_dir
      @logger = logger;
    
    end

    def save(path, contents)
      item_path = File.join(repo_path,path)
      item_directory = File.dirname(item_path)

      FileUtils.mkdir_p(item_directory) unless File.directory? item_directory

      item_handle = File.open(item_path,'w')
      item_handle.write(contents)
      item_handle.close
      repo.add(path)

    end

    def last_item(type)
      case type
      when :bill
        sub_path = "bill"
        ext = ".md"
      else
        raise NotImplemented, "#{type} is not supported"
      end
      Dir[File.join(repo_path,sub_path,"*#{ext}")].map { |i| File.basename(i,ext).to_i }.sort.last        
    end

  end

end