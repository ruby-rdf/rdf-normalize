module RDF::Normalize
  class URDNA2015
    include RDF::Enumerable
    include Base
    include Utils

    ##
    # Create an enumerable with grounded nodes
    #
    # @param [RDF::Enumerable] enumerable
    # @return [RDF::Enumerable]
    def initialize(enumerable, options)
      @dataset, @options = enumerable, options
    end

    def each(&block)
      ns = NormalizationState.new(@options)

      # Map BNodes to the statements they are used by
      dataset.each_statement do |statement|
        statement.to_quad.compact.select(&:node?).each do |node|
          ns.add_statement(node, statement)
        end
      end

      non_normalized_identifiers, simple = ns.bnode_to_statements.keys, true

      while simple
        simple = false
        ns.hash_to_bnodes = {}

        # Calculate hashes for first degree nodes
        non_normalized_identifiers.each do |node|
          hash = depth {ns.hash_first_degree_quads(node)}
          debug("1deg") {"hash: #{hash}"}
          ns.add_bnode_hash(node, hash)
        end

        # Create canonical replacements for hashes mapping to a single node
        ns.hash_to_bnodes.keys.sort.each do |hash|
          identifier_list = ns.hash_to_bnodes[hash]
          next if identifier_list.length > 1
          node = identifier_list.first
          id = ns.canonical_issuer.issue_identifier(node)
          debug("single node") {"node: #{node.to_ntriples}, hash: #{hash}, id: _:#{id}"}
          non_normalized_identifiers -= identifier_list
          ns.hash_to_bnodes.delete(hash)
          simple = true
        end
      end

      # Iterate over hashs having more than one node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]

        debug("multiple nodes") {"node: #{identifier_list.map(&:to_ntriples).join(",")}, hash: #{hash}"}
        hash_path_list = []

        # Create a hash_path_list for all bnodes using a temporary identifier used to create canonical replacements
        identifier_list.each do |identifier|
          next if ns.canonical_issuer.issued.include?(identifier)
          temporary_issuer = IdentifierIssuer.new("b")
          temporary_issuer.issue_identifier(identifier)
          hash_path_list << depth {ns.hash_n_degree_quads(identifier, temporary_issuer)}
        end
        debug("->") {"hash_path_list: #{hash_path_list.map(&:first).inspect}"}

        # Create canonical replacements for nodes
        hash_path_list.sort_by(&:first).map(&:last).each do |issuer|
          issuer.issued.each do |node|
            id = ns.canonical_issuer.issue_identifier(node)
            debug("-->") {"node: #{node.to_ntriples}, id: _:#{id}"}
          end
        end
      end

      # Yield statements using BNodes from canonical replacements
      dataset.each_statement do |statement|
        if statement.has_blank_nodes?
          quad = statement.to_quad.compact.map do |term|
            term.node? ? RDF::Node.intern(ns.canonical_issuer.identifier(term)) : term
          end
          block.call RDF::Statement.from(quad)
        else
          block.call statement
        end
      end
    end

  private

    class NormalizationState
      include Utils

      attr_accessor :bnode_to_statements
      attr_accessor :hash_to_bnodes
      attr_accessor :canonical_issuer

      def initialize(options)
        @options = options
        @bnode_to_statements, @hash_to_bnodes, @canonical_issuer = {}, {}, IdentifierIssuer.new("c14n")
      end

      def add_statement(node, statement)
        bnode_to_statements[node] ||= []
        bnode_to_statements[node] << statement unless bnode_to_statements[node].include?(statement)
      end

      def add_bnode_hash(node, hash)
        hash_to_bnodes[hash] ||= []
        hash_to_bnodes[hash] << node unless hash_to_bnodes[hash].include?(node)
      end

      # @param [RDF::Node] node
      # @return [String] the SHA1 hexdigest hash of statements using this node, with replacements
      def hash_first_degree_quads(node)
        quads = bnode_to_statements[node].
          map do |statement|
            quad = statement.to_quad.map do |t|
              case t
              when node then RDF::Node("a")
              when RDF::Node then RDF::Node("z")
              else t
              end
            end
            RDF::NQuads::Writer.serialize(RDF::Statement.from(quad))
          end

        debug("1deg") {"node: #{node}, quads: #{quads}"}
        hexdigest(quads.sort.join)
      end

      # @param [RDF::Node] related
      # @param [RDF::Statement] statement
      # @param [IdentifierIssuer] issuer
      # @param [String] position one of :s, :o, or :g
      # @return [String] the SHA1 hexdigest hash
      def hash_related_node(related, statement, issuer, position)
        identifier = canonical_issuer.identifier(related) ||
                     issuer.identifier(related) ||
                     hash_first_degree_quads(related)
        input = position.to_s
        input << statement.predicate.to_ntriples unless position == :g
        input << identifier
        hexdigest(input)
      end

      # @param [RDF::Node] identifier
      # @param [IdentifierIssuer] issuer
      # @return [Array<String,IdentifierIssuer>] the Hash and issuer
      def hash_n_degree_quads(identifier, issuer)
        debug("ndeg") {"identifier: #{identifier.to_ntriples}"}

        # hash to related blank nodes map
        map = {}

        bnode_to_statements[identifier].each do |statement|
          hash_statement(identifier, statement, issuer, map)
        end

        data_to_hash = ""

        debug("ndeg") {"map: #{map.map {|h,l| "#{h}: #{l.map(&:to_ntriples)}"}.join('; ')}"}
        depth do
          map.keys.sort.each do |hash|
            list = map[hash]
            # Iterate over related nodes
            chosen_path, chosen_issuer = "", nil

            list.permutation do |permutation|
              debug("ndeg") {"perm: #{permutation.map(&:to_ntriples).join(",")}"}
              issuer_copy, path, recursion_list = issuer.dup, "", []

              permutation.each do |related|
                if canon = canonical_issuer.identifier(related)
                  path << canon
                elsif !issuer_copy.identifier(related)
                  recursion_list << related
                  path << issuer_copy.issue_identifier(related)
                elsif !chosen_path.empty? && path.length >= chosen_path.length
                  break # skip to next permutation
                end
              end
              debug("ndeg") {"hash: #{hash}, path: #{path.inspect}, recursion: #{recursion_list.map(&:to_ntriples)}"}

              recursion_list.each do |related|
                result = depth {hash_n_degree_quads(related, issuer_copy)}
                path << issuer_copy.issue_identifier(related)
                path << "<#{result.first}>"
                issuer_copy = result.last
                break if !chosen_path.empty? && path.length >= chosen_path.length && path > chosen_path
              end

              if chosen_path.empty? || path < chosen_path
                chosen_path, chosen_issuer = path, issuer_copy
              end
            end

            data_to_hash += chosen_path
            issuer = chosen_issuer
          end
        end

        return [hexdigest(data_to_hash), issuer]
      end

      protected

      # FIXME: should be SHA-256.
      def hexdigest(val)
        Digest::SHA1.hexdigest(val)
      end

      # Group adjacent bnodes by hash
      def hash_statement(identifier, statement, issuer, map)
        statement.to_hash(:s, :p, :o, :g).each do |pos, term|
          next if !term.is_a?(RDF::Node) || term == identifier

          hash = depth {hash_related_node(term, statement, issuer, pos)}
          map[hash] ||= []
          map[hash] << term unless map[hash].include?(term)
        end
      end
    end

    class IdentifierIssuer 
      def initialize(prefix = "c14n")
        @prefix, @counter, @issued = prefix, 0, {}
      end

      # Return an identifier for this BNode
      def issue_identifier(node)
        @issued[node] ||= begin
          res, @counter = @prefix + @counter.to_s, @counter + 1
          res
        end
      end

      def issued
        @issued.keys
      end

      def identifier(node)
        @issued[node]
      end
    end
  end
end