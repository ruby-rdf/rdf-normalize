module RDF::Normalize
  class Format < RDF::Format
    content_encoding 'utf-8'

    writer { RDF::Normalize::Writer }
  end
end
