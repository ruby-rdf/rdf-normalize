module RDF::Normalize
  class URDNA2015
    include RDF::Enumerable
    include Base

    ##
    # Create an enumerable with grounded nodes
    #
    # @param [RDF::Enumerable] enumerable
    # @return [RDF::Enumerable]
    def initialize(enumerable, options)
      @dataset = enumerable
    end

    def each(&block)
      ns = NormalizationState.new

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
          hash = ns.hash_first_degree_quads(node)
          ns.add_bnode_hash(node, hash)
        end

        # Create canonical replacements for hashes mapping to a single node
        ns.hash_to_bnodes.keys.sort.each do |hash|
          identifier_list = ns.hash_to_bnodes[hash]
          next if identifier_list.length > 1
          node = identifier_list.first
          ns.canonical_issuer.issue_identifier(node)
          non_normalized_identifiers -= identifier_list
          ns.hash_to_bnodes.delete(hash)
          simple = true
        end
      end

      # Iterate over hashs having more than one node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]
        hash_path_list = []

        # Create a hash_path_list for all bnodes using a temporary identifier used to create canonical replacements
        identifier_list.each do |identifier|
          next if ns.canonical_issuer.issued.include?(identifier)
          temporary_issuer = IdentifierIssuer.new("b")
          temporary_issuer.issue_identifier(identifier)
          hash_path_list << ns.hash_n_degree_quads(identifier, temporary_issuer)
        end

        # Create canonical replacements for nodes
        hash_path_list.sort_by(&:first).map(&:last).each do |issuer|
          issuer.issued.each do |node|
            ns.canonical_issuer.issue_identifier(node)
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
      attr_accessor :bnode_to_statements
      attr_accessor :hash_to_bnodes
      attr_accessor :canonical_issuer

      def initialize
        @bnode_to_statements, @hash_to_bnodes, @canonical_issuer = {}, {}, IdentifierIssuer.new("c14n")
      end

      def add_statement(node, statement)
        (bnode_to_statements[node] ||= []) << statement
      end

      def add_bnode_hash(node, hash)
        (hash_to_bnodes[hash] ||= []) << node
      end

      # @param [RDF::Node] node
      # @return [String] the SHA256 hexdigest hash of statements using this node, with replacements
      def hash_first_degree_quads(node)
        quads = bnode_to_statements.
          fetch(node, []).
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

        Digest::SHA256.hexdigest(quads.sort.join)
      end

      # @param [RDF::Node] target SPEC CONFUSION: not used in algorithm
      # @param [RDF::Node] related
      # @param [RDF::Statement] statement
      # @param [IdentifierIssuer] issuer
      # @param [String] position one of :s, :o, or :g
      # @return [String] the SHA256 hexdigest hash
      def hash_related_node(target, related, statement, issuer, position)
        identifier = canonical_issuer.identifier(related) ||
                     issuer.identifier(related) ||
                     hash_first_degree_quads(related)
        input = position.to_s
        input << statement.predicate.to_ntriples unless position == :g
        input << identifier
        Digest::SHA256.hexdigest(input)
      end

      # @param [RDF::Node] node
      # @param [IdentifierIssuer] issuer
      # @return [Array<String,IdentifierIssuer>] the Hash and issuer
      def hash_n_degree_quads(node, issuer)
        map = {}
        bnode_to_statements.fetch(node, []).each do |statement|
          statement.to_hash.each do |position, term|
            next unless term.is_a?(RDF::Node)

            pos = case position
            when :subject   then :s
            when :predicate then :p # for good measure
            when :object    then :o
            when :context   then :g
            end

            hash = hash_related_node(node, term, statement, issuer, pos)
            (map[hash] ||= []) << node

          end
        end

        # Iterate over related nodes
        # SPEC CONFUSION: This terminates after the first entry
        map.keys.sort.each do |hash|
          list = map.fetch(hash, [])
          chosen_path, chosen_issuer = "", nil

          list.permutation do |permutation|
            issuer_copy, path, recursion_list = issuer, "", []

            permutation.each do |related|
              if canon = canonical_issuer.identifier(related)
                path << canon
              elsif !issuer_copy.identifier(related)
                recursion_list << related
                path << issuer_copy.issue_identifier(related)
              elsif !chosen_path.empty? && path.length >= chosen_path.length
                break
              end
            end

            recursion_list.each do |related|
              result = hash_n_degree_quads(related, issuer_copy)
              path << issuer_copy.issue_identifier(related)
              path << "<#{result.first}>"
              issuer_copy = result.last
              break if !chosen_path.empty? && path.length >= chosen_path.length && path > chosen_path
            end

            if chosen_path.empty? || path < chosen_path
              chosen_path, chosen_issuer = path, issuer_copy
            end
          end

          # Seems like this should be out one more level
          # SPEC CONFUSION: nomenclature is very confusing
          return [Digest::SHA256.hexdigest((map.keys + [chosen_path]).join("")), chosen_issuer]
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