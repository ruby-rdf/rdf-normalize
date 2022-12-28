#!/usr/bin/env ruby
require 'rubygems'
require 'psych'
require 'haml'
require 'cgi'
require 'getoptlong'
require 'byebug'
require 'amazing_print'

HAML_ARRAY = %(
%ul{class: (property && property.to_s.gsub('.', '-'))}
  - input.each do |el|
    - if %i(nquads hndq2).include?(property)
      %li= serialize_quad(el)
    - else
      %li= serialize(el, property: property)
)

HAML_TEMPLATES = {
  bn_to_quads: %(
    %table.bn_to_quads
      %thead
        %tr
          %th
            %var="blank node"
          %th
            %var="Q"
      %tbody
        - input.each do |bn, quads|
          %tr
            %td
              %code
                %em=bn
            %td
              - quads.each do |quad|
                %code
                  = serialize_quad(quad)
                %br
  ),
  default: %(
    %table.log{class: (property && property.to_s.gsub('.', '-'))}
      %tbody
        - input.each do |prop, value|
          %tr{class: prop.to_s.gsub('.', '-')}
            %td.c0{class: prop.to_s.gsub('.', '-')}
              %code
                - if prop.to_s.match?(/^\w.*\d$/)
                  %em=prop
                - else
                  = prop
            %td.c1{class: prop.to_s.gsub('.', '-')}
              = serialize(value, property: prop.to_sym)
  ),
  doc: %(
    !!!HTML5
    %html{lang: :en}
      %head
        %title~ title
        %meta{charset: 'utf-8'}
        :css
          table.log {
            padding: 5px;
            border-width: 1px;
            border-spacing: 0;
            border-style: solid;
            border-collapse: collapse;
          }
          table.log tr, table.log td {
            padding: 5px;
            border-width: 1px;
            border-spacing: 0;
            border-style: solid;
            border-collapse: collapse;
          }
          table.log ul { padding: 0; margin: 0; }
          table.log td { text-align: left; vertical-align: top; border: solid; }
          table.log td.ca.c0 { display: none; }
          table.log td.bn_to_quads.c0 { display: none; }
          table.log td.identifier.c1 { font-style: italic; }
          table.log li { list-style: none; }
      %body
        = serialize(input)
  )
}

class ::String
  # Trim beginning of each line by the amount of indentation in the first line
  def align_left
    str = self.sub(/^\s*$/, '')  # Remove leading newline
    str = str[1..-1] if str[0,1] == "\n"
    ws = str.match(/^(\s*)\S/m) ? $1 : ''
    str.gsub(/^#{ws}/m, '')
  end
end

def serialize(input, property: nil, **options)
  case input
  when Hash
    template = HAML_TEMPLATES.fetch(property, HAML_TEMPLATES[:default]).align_left
    $stderr.puts({input: input, property: property, template: template}.ai) if options[:debug]
    Haml::Engine.new(template, format: :html5).render(self, input: input, property: property, title: options[:title])
  when Array
    template = HAML_ARRAY.align_left
    $stderr.puts({input: input, property: property, template: template}.ai) if options[:debug]
    Haml::Engine.new(template, format: :html5).render(self, input: input, property: property, title: options[:title])
  when String
    if input.length > 20 && property.to_s.match?(/hash|input/)
      # Abbreviated output
      %(<abbr title="#{input}">#{CGI::escapeHTML(input[0..9])}...#{CGI::escapeHTML(input[-10..-1])}</abbr>)
    elsif property == :quad
      serialize_quad(input)
    else
      CGI::escapeHTML(input)
    end
  when NilClass
    ''
  else
    raise "Can't serialize #{input.class}"
  end
end

def serialize_quad(quad)
  quad.split(' ').map do |r|
    if r.match?(/^\w.*\d$/)
      "<em>#{CGI::escapeHTML(r)}</em>"
    elsif r.start_with?('<http://example.com/#') && r.end_with?('>')
      CGI::escapeHTML(':' + r[21..-2]) # PName variant
    else
      CGI::escapeHTML(r)
    end
  end.join('&nbsp;')
end

options = {
  output: $stdout
}

OPT_ARGS = [
  ["--debug", GetoptLong::NO_ARGUMENT,                "Debug shape matching"],
  ["--output", "-o", GetoptLong::REQUIRED_ARGUMENT,   "Save output to file"],
  ["--help", "-?", GetoptLong::NO_ARGUMENT,           "This message"]
]
def usage
  STDERR.puts %{Usage: #{$0} [options] file}
  width = OPT_ARGS.map do |o|
    l = o.first.length
    l += o[1].length + 2 if o[1].is_a?(String)
    l
  end.max
  OPT_ARGS.each do |o|
    s = "  %-*s  " % [width, (o[1].is_a?(String) ? "#{o[0,2].join(', ')}" : o[0])]
    s += o.last
    STDERR.puts s
  end
  exit(1)
end

opts = GetoptLong.new(*OPT_ARGS.map {|o| o[0..-2]})

input = nil

opts.each do |opt, arg|
  case opt
  when '--debug'        then options[:debug] = true
  when '--output'       then options[:output] = File.open(arg, "w")
  when "--help"         then usage
  end
end

results = if ARGV.empty?
  s = input ? input : $stdin.read
  serialize(Psych.safe_load(s), property: :doc, title: "stdin", **options)
else
  serialize(Psych.safe_load_file(ARGV.first), property: :doc, title: ARGV.first, **options)
end

options[:output].write results