require 'rspec/matchers'
require 'json'

Info = Struct.new(:about, :information, :trace, :input)

RSpec::Matchers.define :produce do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:input)
      info
    elsif info.is_a?(Hash)
      identifier = info[:about]
      trace = info[:trace] || ""
      trace = trace.join("\n") if trace.is_a?(Array)
      Info.new(identifier, info[:information] || "", trace, info[:input])
    else
      Info.new(expected.is_a?(RDF::Graph) ? expected.context : info, info.to_s)
    end
    expect(actual).to eq expected
  end
  
  failure_message do |actual|
    info = @info.respond_to?(:information) ? @info.information : @info.inspect
    "Expected: #{expected.is_a?(String) ? expected : expected.to_json(JSON_STATE) rescue 'malformed json'}\n" +
    "Actual  : #{actual.is_a?(String) ? actual : actual.to_json(JSON_STATE) rescue 'malformed json'}\n" +
    #(expected.is_a?(Hash) && actual.is_a?(Hash) ? "Diff: #{expected.diff(actual).to_json(JSON_STATE) rescue 'malformed json'}\n" : "") +
    "\n#{info + "\n" unless info.empty?}" +
    (@info.input ? "Input file: #{@info.input}\n" : "") +
    (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
  end
end
