module RDF::Normalize
  class URDNA2012 < URDNA2015
    class NormalizationState < URDNA2015::NormalizationState
      protected

      # 2012 version uses SHA-1
      def hexdigest(val)
        Digest::SHA1.hexdigest(val)
      end

      # In URGNA2012, the position parameter passed to the Hash Related Blank Node algorithm was instead modeled as a direction parameter, where it could have the value p, for property, when the related blank node was a `subject` and the value r, for reverse or reference, when the related blank node was an `object`. Since URGNA2012 only normalized graphs, not datasets, there was no use of the `graph` position.
      def hash_position(term, statement, issuer, pos)
        pos = {s: :p, p: :P, o: :r, g: :g}[pos]
        depth {hash_related_node(term, statement, issuer, pos)}
      end
    end
  end
end