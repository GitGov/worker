module GitGov
  module Models
    class RepoItem
      attr_accessor :type
      attr_accessor :key
      attr_reader :repo
      def markdown()
        raise NotImplemented, "This function has not been implemented"
      end

      def location(type)

        case type

        when :relative
          File.join(@type.to_s,"#{@key}.md")
        when :repo
          File.join(repo.repo_path,location(:relative))
        else
          raise NotImplemented, "#{type} is not a valid location type"
        end
      end

    end
  end
end