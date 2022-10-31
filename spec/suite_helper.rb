$:.unshift "."
require 'spec_helper'
require 'json/ld'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "https://w3c.github.io/rch-rdc/"
    LOCAL_PATH = ::File.expand_path("../../../rch-rdc", __FILE__) + '/'

    class << self
      alias_method :original_open_file, :open_file
    end

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, **options, &block)
      case
      when filename_or_url.to_s =~ /^file:/
        path = filename_or_url.to_s[5..-1]
        Kernel.open(path.to_s, &block)
      when (filename_or_url.to_s =~ %r{^#{REMOTE_PATH}} && ::File.exist?(filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)))
        begin
          #puts "attempt to open #{filename_or_url} locally"
          localpath = filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
          response = begin
            ::File.open(localpath)
          rescue Errno::ENOENT
            Kernel.open(filename_or_url.to_s, "r:utf-8", 'Accept' => "application/n-quads, application/n-triples")
          end
          document_options = {
            base_uri:     RDF::URI(filename_or_url, {}),
            charset:      Encoding::UTF_8,
            code:         200,
            headers:      {}
          }
          #puts "use #{filename_or_url} locally"
          document_options[:headers][:content_type] = case filename_or_url.to_s
          when /\.nq$/    then 'application/n-quads'
          when /\.nt$/    then 'application/n-triples'
          when /\.csv$/    then 'text/csv'
          when /\.tsv$/    then 'text/tsv'
          when /\.json$/   then 'application/json'
          when /\.jsonld$/ then 'application/ld+json'
          else                  'unknown'
          end

          document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
          # For overriding content type from test data
          document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

          # For overriding Link header from test data
          document_options[:headers][:link] = options[:httpLink] if options[:httpLink]

          remote_document = RDF::Util::File::RemoteDocument.new(response.read, **document_options)
          if block_given?
            yield remote_document
          else
            remote_document
          end
        end
      else
        original_open_file(filename_or_url, **options, &block)
      end
    end
  end
end

module Fixtures
  module SuiteTest
    BASE = "https://w3c.github.io/rch-rdc/tests/"
    class Manifest < JSON::LD::Resource
      def self.open(file, base)
        #puts "open: #{file}"
        RDF::Util::File.open_file(file) do |file|
          json = ::JSON.load(file.read)
          yield Manifest.new(json, context: json['@context'].merge('@base' => base))
        end
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e, context: context)}
      end
    end
 
    class Entry < JSON::LD::Resource
      attr_accessor :logger
      attr_accessor :metadata

      def id
        attributes['id']
      end

      def base
        action
      end

      # Apply base to action and result
      def action
        RDF::URI(context['@base']).join(attributes["action"]).to_s
      end

      def result
        RDF::URI(context['@base']).join(attributes["result"]).to_s
      end

      def input
        @input ||= RDF::Util::File.open_file(action) {|f| f.read}
      end

      def expected
        @expected ||= RDF::Util::File.open_file(result) {|f| f.read}
      end

      def writer_options
        res = {}
        res[:algorithm] = type.sub('rdfn:', '').sub('EvalTest', '').downcase.to_sym
        res
      end
    end
  end
end
