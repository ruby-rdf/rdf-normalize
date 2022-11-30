module RDF::Normalize
  class URDNA2015
    include RDF::Enumerable
    include RDF::Util::Logger
    include Base

    ##
    # Create an enumerable with grounded nodes
    #
    # @param [RDF::Enumerable] enumerable
    # @return [RDF::Enumerable]
    def initialize(enumerable, **options)
      @dataset, @options = enumerable, options
    end

    def each(&block)
      ns = NormalizationState.new(@options)
      normalize_statements(ns, &block)
    end

    protected
    def normalize_statements(ns, &block)
      # Map BNodes to the statements they are used by
      dataset.each_statement do |statement|
        statement.to_quad.compact.select(&:node?).each do |node|
          ns.add_statement(node, statement)
        end
      end

      ns.hash_to_bnodes = {}

      # Calculate hashes for first degree nodes
      ns.bnode_to_statements.each_key do |node|
        log_debug("ca") {"1deg: #{node}"}
        hash = log_depth {ns.hash_first_degree_quads(node)}
        ns.add_bnode_hash(node, hash)
      end

      # Create canonical replacements for hashes mapping to a single node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]
        next if identifier_list.length > 1
        node = identifier_list.first
        id = ns.canonical_issuer.issue_identifier(node)
        log_debug("ca", "single node") {"node: #{node.to_ntriples}, hash: #{hash}, id: #{id}"}
        ns.hash_to_bnodes.delete(hash)
      end

      # Iterate over hashs having more than one node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]

        log_debug("ca", "multiple nodes") {"node: #{identifier_list.map(&:to_nquads).map(&:strip).join(",")}, hash: #{hash}"}
        hash_path_list = []

        # Create a hash_path_list for all bnodes using a temporary identifier used to create canonical replacements
        identifier_list.each do |identifier|
          next if ns.canonical_issuer.issued.include?(identifier)
          temporary_issuer = IdentifierIssuer.new("_:b")
          temporary_issuer.issue_identifier(identifier)
          hash_path_list << log_depth {ns.hash_n_degree_quads(identifier, temporary_issuer)}
        end
        log_debug("ca") {"hash_path_list: #{hash_path_list.inspect}"}

        # Create canonical replacements for nodes
        hash_path_list.sort_by(&:first).map(&:last).each do |issuer|
          issuer.issued.each do |node|
            id = ns.canonical_issuer.issue_identifier(node)
            log_debug("-->") {"node: #{node.to_ntriples}, id: #{id}"}
          end
        end
      end

      # Yield statements using BNodes from canonical replacements
      dataset.each_statement do |statement|
        if statement.has_blank_nodes?
          quad = statement.to_quad.compact.map do |term|
            term.node? ? RDF::Node.intern(ns.canonical_issuer.identifier(term)[2..-1]) : term
          end
          block.call RDF::Statement.from(quad)
        else
          block.call statement
        end
      end
    end

  private

    class NormalizationState
      include RDF::Util::Logger

      attr_accessor :bnode_to_statements
      attr_accessor :hash_to_bnodes
      attr_accessor :canonical_issuer

      def initialize(options)
        @options = options
        @bnode_to_statements, @hash_to_bnodes, @canonical_issuer = {}, {}, IdentifierIssuer.new("_:c14n")
      end

      def add_statement(node, statement)
        bnode_to_statements[node] ||= []
        bnode_to_statements[node] << statement unless bnode_to_statements[node].any? {|st| st.eql?(statement)}
      end

      def add_bnode_hash(node, hash)
        hash_to_bnodes[hash] ||= []
        # Match on object IDs of nodes, rather than simple node equality
        hash_to_bnodes[hash] << node unless hash_to_bnodes[hash].any? {|n| n.eql?(node)}
      end

      # This algorithm calculates a hash for a given blank node across the quads in a dataset in which that blank node is a component. If the hash uniquely identifies that blank node, no further examination is necessary. Otherwise, a hash will be created for the blank node using the algorithm in [4.9 Hash N-Degree Quads](https://w3c.github.io/rdf-canon/spec/#hash-nd-quads) invoked via [4.5 Canonicalization Algorithm](https://w3c.github.io/rdf-canon/spec/#canon-algorithm).
      #
      # @param [RDF::Node] node The reference blank node identifier
      # @return [String] the SHA256 hexdigest hash of statements using this node, with replacements
      def hash_first_degree_quads(node)
        log_debug("1deg") {"input: #{bnode_to_statements[node].map(&:to_nquads).map(&:strip).join(' ')}"}
        nquads = bnode_to_statements[node].
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

        log_debug("1deg") {"nquads: #{nquads.map(&:strip).join(' ')}"}
        result = hexdigest(nquads.sort.join)
        log_debug("1deg") {"hash: #{result}"}
        result
      end

      # @param [RDF::Node] related
      # @param [RDF::Statement] statement
      # @param [IdentifierIssuer] issuer
      # @param [String] position one of :s, :o, or :g
      # @return [String] the SHA256 hexdigest hash
      def hash_related_node(related, statement, issuer, position)
        log_debug("hrel") {"related: #{related.to_nquads}, position: #{position}"}
        log_debug("hrel") {"predicate: #{statement.predicate.to_nquads}, position: #{position}"}
        identifier = canonical_issuer.identifier(related) ||
                     issuer.identifier(related) ||
                     hash_first_degree_quads(related)
        input = "#{position}"
        input << statement.predicate.to_ntriples unless position == :g
        input << identifier
        log_debug("hrel") {"input: #{input.inspect}, hash: #{hexdigest(input)}"}
        hexdigest(input)
      end

      # @param [RDF::Node] identifier
      # @param [IdentifierIssuer] issuer
      # @return [Array<String,IdentifierIssuer>] the Hash and issuer
      def hash_n_degree_quads(identifier, issuer)
        log_debug("ndeg") {"canon issuer: #{canonical_issuer.inspect}"}
        log_debug("ndeg") {"identifier: #{identifier.to_ntriples}"}
        log_debug("ndeg") {"issuer: #{issuer.inspect}"}

        # hash to related blank nodes map
        hn = {}

        log_debug("ndeg") {"quads: #{bnode_to_statements[identifier].map(&:to_nquads).map(&:strip).join(' ')}"}

        bnode_to_statements[identifier].each do |statement|
          log_depth {hash_related_statement(identifier, statement, issuer, hn)}
        end
        log_debug("ndeg") {"hn: #{hn.map {|h,l| "#{h}: #{l.map(&:to_ntriples)}"}.join('; ')}"}

        data_to_hash = ""

        log_depth do
          hn.keys.sort.each do |hash|
            list = hn[hash]
            # Iterate over related nodes
            chosen_path, chosen_issuer = "", nil
            data_to_hash += hash

            list.permutation do |permutation|
              log_debug("ndeg") {"perm: #{permutation.map(&:to_ntriples).join(", ")}"}
              issuer_copy, path, recursion_list = issuer.dup, "", []

              permutation.each do |related|
                if canonical_issuer.identifier(related)
                  path << canonical_issuer.issue_identifier(related)
                else
                  recursion_list << related if !issuer_copy.identifier(related)
                  path << issuer_copy.issue_identifier(related)
                end

                # Skip to the next permutation if chosen path isn't empty and the path is greater than the chosen path
                break if !chosen_path.empty? && path.length >= chosen_path.length
              end
              log_debug("ndeg") {"hash: #{hash}, path: #{path}, recursion: #{recursion_list.map(&:to_ntriples)}"}

              recursion_list.each do |related|
                result = log_depth {hash_n_degree_quads(related, issuer_copy)}
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

        log_debug("ndeg") {"datatohash: #{data_to_hash.inspect}, hash: #{hexdigest(data_to_hash)}"}
        return [hexdigest(data_to_hash), issuer]
      end

      protected

      def hexdigest(val)
        Digest::SHA256.hexdigest(val)
      end

      # Group adjacent bnodes by hash
      def hash_related_statement(identifier, statement, issuer, map)
        statement.to_h(:s, :p, :o, :g).each do |pos, term|
          next if !term.is_a?(RDF::Node) || term == identifier

          hash = log_depth {hash_related_node(term, statement, issuer, pos)}
          map[hash] ||= []
          map[hash] << term unless map[hash].any? {|n| n.eql?(term)}
        end
      end
    end

    class IdentifierIssuer 
      def initialize(prefix = "_:c14n")
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

      # Duplicate this issuer, ensuring that the issued identifiers remain distinct
      # @return [IdentifierIssuer]
      def dup
        other = super
        other.instance_variable_set(:@issued, @issued.dup)
        other
      end

      def inspect
        "Issuer: #{@issued.map {|k,v| "#{k}: #{v}"}.join(', ')}"
      end
    end
  end
end
