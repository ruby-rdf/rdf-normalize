require 'rdf/nquads'

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
      # Step 2: Map BNodes to the statements they are used by
      dataset.each_statement do |statement|
        statement.to_quad.compact.select(&:node?).each do |node|
          ns.add_statement(node, statement)
        end
      end
      log_debug("ca", "step 2") {"bn to quads: #{ns.inspect_bnode_to_statements}"}

      ns.hash_to_bnodes = {}

      # Step 3: Calculate hashes for first degree nodes
      ns.bnode_to_statements.each_key do |node|
        hash = log_depth {ns.hash_first_degree_quads(node)}
        ns.add_bnode_hash(node, hash)
      end

      # Step 4: Create canonical replacements for hashes mapping to a single node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]
        next if identifier_list.length > 1
        node = identifier_list.first
        id = ns.canonical_issuer.issue_identifier(node)
        log_debug("ca", "step 4.2") {"identifier: #{node.id}, hash: #{hash}, cid: #{id[2..-1]}"}
        ns.hash_to_bnodes.delete(hash)
      end

      # Step 5: Iterate over hashs having more than one node
      ns.hash_to_bnodes.keys.sort.each do |hash|
        identifier_list = ns.hash_to_bnodes[hash]

        log_debug("ca", "step 5.1") {"identifier_list: #{identifier_list.map(&:to_nquads).map(&:strip).join(",")}, hash: #{hash}"}
        hash_path_list = []

        # Create a hash_path_list for all bnodes using a temporary identifier used to create canonical replacements
        identifier_list.each do |identifier|
          next if ns.canonical_issuer.issued.include?(identifier)
          temporary_issuer = IdentifierIssuer.new("_:b")
          temporary_issuer.issue_identifier(identifier)
          hash_path_list << log_depth {ns.hash_n_degree_quads(identifier, temporary_issuer)}
        end
        log_debug("ca", "step 5.2") {"hash_path_list: #{hash_path_list.inspect}"}

        # Create canonical replacements for nodes
        hash_path_list.sort_by(&:first).map(&:last).each do |issuer|
          issuer.issued.each do |node|
            id = ns.canonical_issuer.issue_identifier(node)
            log_debug("ca", "step 5.3.1") {"node: #{node.id}, cid: #{id}"}
          end
        end
      end

      # Step 6: Yield statements using BNodes from canonical replacements
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

      log_debug("ca", "exit") {ns.canonical_issuer.inspect}
      dataset
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
        log_debug("h1d", "entry") {"identifier: #{node.id}"}
        nquads = bnode_to_statements[node].
          map do |statement|
            quad = statement.to_quad.map do |t|
              case t
              when node then RDF::Node("a")
              when RDF::Node then RDF::Node("z")
              else t
              end
            end
            RDF::Statement.from(quad).to_nquads
          end
        log_debug("h1d", "exit") {"nquads: #{nquads.map(&:strip)}"}

        result = hexdigest(nquads.sort.join)
        log_debug("h1d", "exit") {"hash: #{result}"}
        result
      end

      # @param [RDF::Node] related
      # @param [RDF::Statement] statement
      # @param [IdentifierIssuer] issuer
      # @param [String] position one of :s, :o, or :g
      # @return [String] the SHA256 hexdigest hash
      def hash_related_node(related, statement, issuer, position)
        log_debug("hrbn", "entry") {"related: #{related.to_nquads}, position: #{position}"}
        log_debug("hrbn", "entry") {"quad: #{statement.to_nquads.strip}"}
        input = "#{position}"
        input << statement.predicate.to_ntriples unless position == :g
        if identifier = (canonical_issuer.identifier(related) ||
                         issuer.identifier(related))
          input << identifier.to_s
        else
          input << log_depth {hash_first_degree_quads(related)}
        end
        log_debug("hrbn", "exit") {"input: #{input.inspect}, hash: #{hexdigest(input)}"}
        hexdigest(input)
      end

      # @param [RDF::Node] identifier
      # @param [IdentifierIssuer] issuer
      # @return [Array<String,IdentifierIssuer>] the Hash and issuer
      def hash_n_degree_quads(identifier, issuer)
        log_debug("hndq", "entry") {"identifier: #{identifier.id}"}
        log_debug("hndq", "entry") {issuer.inspect}

        # hash to related blank nodes map
        hn = {}

        log_debug("hndq", "step 2") {"quads: #{bnode_to_statements[identifier].map(&:to_nquads).map(&:strip).join(' ')}"}

        # Step 3
        bnode_to_statements[identifier].each do |statement|
          log_depth {hash_related_statement(identifier, statement, issuer, hn)}
        end
        log_debug("hndq", "step 3") {"hn: #{hn.map {|h,l| "#{h}: #{l.map(&:to_ntriples)}"}.join('; ')}"}

        data_to_hash = ""

        log_depth do
          # Step 5
          hn.keys.sort.each do |hash|
            log_debug("hndq", "step 5") {"hash: #{hash}, data_to_hash: #{data_to_hash}"}
            list = hn[hash]
            # Iterate over related nodes
            chosen_path, chosen_issuer = "", nil
            data_to_hash += hash

            list.permutation do |permutation|
              log_debug("hndq", "step 5.4") {"perm: #{permutation.map(&:id).join(", ")}"}
              issuer_copy, path, recursion_list = issuer.dup, "", []

              permutation.each do |related|
                log_debug("hndq", "step 5.4.4") {"related: #{related}, path: #{path}"}
                if canonical_issuer.identifier(related)
                  path << canonical_issuer.issue_identifier(related)
                else
                  recursion_list << related if !issuer_copy.identifier(related)
                  path << issuer_copy.issue_identifier(related)
                end

                # Skip to the next permutation if chosen path isn't empty and the path is greater than the chosen path
                break if !chosen_path.empty? && path.length >= chosen_path.length
              end

              log_debug("hndq", "step 5.4.5") {"recursion_list: #{recursion_list.map(&:to_ntriples)}, path: #{path}"}
              recursion_list.each do |related|
                result = log_depth {hash_n_degree_quads(related, issuer_copy)}
                path << issuer_copy.issue_identifier(related)
                path << "<#{result.first}>"
                issuer_copy = result.last
                log_debug("hndq", "step 5.4.5.5") {"path: #{path}, issuer copy: #{issuer_copy.inspect}"}
                break if !chosen_path.empty? && path.length >= chosen_path.length && path > chosen_path
              end

              if chosen_path.empty? || path < chosen_path
                chosen_path, chosen_issuer = path, issuer_copy
              end
            end

            data_to_hash += chosen_path
            log_debug("hndq", "step 5.6") {"chosen_path: #{chosen_path}, data_to_hash: #{data_to_hash}"}
            issuer = chosen_issuer
          end
        end

        log_debug("hndq") {"hash: #{hexdigest(data_to_hash)}, #{issuer.inspect}"}
        return [hexdigest(data_to_hash), issuer]
      end

      def inspect
        "NormalizationState:\nbnode_to_statements: #{inspect_bnode_to_statements}\nhash_to_bnodes: #{inspect_hash_to_bnodes}\ncanonical_issuer: #{canonical_issuer.inspect}"
      end

      def inspect_bnode_to_statements
        bnode_to_statements.map do |n, statements|
          "#{n.id}: #{statements.map {|s| s.to_nquads.strip}}"
        end.join(", ")
      end

      def inspect_hash_to_bnodes
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
