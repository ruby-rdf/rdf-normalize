module RDF::Normalize
  ##
  # A RDF Graph normalization serialiser.
  #
  # Normalizes the enumerated statements into normal form in the form of N-Quads.
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::NQuads::Writer
    format RDF::Normalize::Format

    # @attr_accessor [RDF::Repository] Repository of statements to serialized
    attr_accessor :repo

    ##
    # Initializes the writer instance.
    #
    # @param  [IO, File] output
    #   the output stream
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @yield  [writer] `self`
    # @yieldparam  [RDF::Writer] writer
    # @yieldreturn [void]
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super do
        @repo = RDF::Repository.new
        if block_given?
          case block.arity
            when 0 then instance_eval(&block)
            else block.call(self)
          end
        end
      end
    end

    ##
    # Defer writing to epilogue
    def write_statement(statement)
      self
    end

    ##
    # Outputs the Graph representation of all stored triples.
    #
    # @return [void]
    def write_epilogue
      statements = RDF::Normalize.new(@repo, @options).
        statements.
        reject(&:variable?).
        map {|s| format_statement(s)}.
        sort.
        each do |line|
          puts line
        end
      super
    end

    protected

    ##
    # Adds a statement to be serialized
    # @param  [RDF::Statement] statement
    # @return [void]
    def insert_statement(statement)
      @repo.insert(statement)
    rescue ArgumentError => e
      log_error e.message
    end

    ##
    # Insert an Enumerable
    #
    # @param  [RDF::Enumerable] graph
    # @return [void]
    def insert_statements(enumerable)
      @repo = enumerable
    end
  end
end
