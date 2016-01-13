#!/usr/bin/env ruby

require 'optparse'
require 'bio-logger'
require 'csv'
require 'pry'

SCRIPT_NAME = File.basename(__FILE__); LOG_NAME = SCRIPT_NAME.gsub('.rb','')

# Parse command line options into the options hash
options = {
  :logger => 'stderr',
  :log_level => 'info',
}
o = OptionParser.new do |opts|
  opts.banner = "
    Usage: #{SCRIPT_NAME} <arguments>

Converts the text copied from the NCBI webpage
http://www.ncbi.nlm.nih.gov/Taxonomy/taxonomyhome.html/index.cgi?chapter=tgencodes
and converts it to C code that can be put into orfm.c
\n\n"

  # logger options
  opts.separator "\nVerbosity:\n\n"
  opts.on("-q", "--quiet", "Run quietly, set logging to ERROR level [default INFO]") {options[:log_level] = 'error'}
  opts.on("--logger filename",String,"Log to file [default #{options[:logger]}]") { |name| options[:logger] = name}
  opts.on("--trace options",String,"Set log level [default INFO]. e.g. '--trace debug' to set logging level to DEBUG"){|s| options[:log_level] = s}
end; o.parse!
if ARGV.length != 0
  $stderr.puts o
  exit 1
end
# Setup logging
Bio::Log::CLI.logger(options[:logger]); Bio::Log::CLI.trace(options[:log_level]); log = Bio::Log::LoggerPlus.new(LOG_NAME); Bio::Log::CLI.configure(LOG_NAME); log.outputters[0].formatter = Log4r::PatternFormatter.new(:pattern => "%5l %c %d: %m", :date_pattern => '%d/%m %T')


puts "///////// AUTOGENERATED CODE, DO NOT EDIT DIRECTLY"

current_table = nil
current_table_number = 0
table_names = {}

codon_to_position = {}
bases ="ACGT"
codon_list = []
order = bases.split('').collect do |c1|
  bases.split('').collect do |c2|
    bases.split('').collect do |c3|
      k = "#{c1}#{c2}#{c3}"
      codon_list.push k
    end
  end
end.flatten
codon_list.each_with_index do |codon, position|
  codon_to_position[codon] = position
end

print_table = lambda do
  table_name = "codonTable#{current_table_number}"
  puts "char #{table_name}[] = {"
  order = codon_list.collect do |k|
    raise unless current_table.key?(k)
    #puts [k, current_table[k]].join(' ')
    if current_table[k] == '*' and current_table[k.tr('ATGC','TACG').reverse] == '*'
      $stderr.puts "Gah on #{k} in #{table_name}, fwd and rev are both stop codons"
      '!'
    else
      current_table[k]
    end
  end
  puts "    '"+order.join("', '")+"'"
  puts "};"

  table_names[current_table_number] = table_name
end


File.open(File.join(File.dirname(__FILE__), 'copy_from_ncbi.txt')).each do |line|
  row = line.strip.split(' ')
  next if row.empty?

  # e.g.
  # 6. The Ciliate, Dasycladacean and Hexamita Nuclear Code (transl_table=6)
  if matches = row[0].match(/^(\d+)\.$/)
    print_table.call unless current_table.nil?
    num = matches[1].to_i
    current_table_number = num
    current_table = {}
  else
    row.reject! {|e| e=='i' or e.nil?}

    # e.g.
    # ATG M Met i    ACG T Thr      AAG K Lys      AGG R Arg
    if row.length==12 and row[0].length == 3
      [0,3,6,9].each do |i|
        current_table[row[i]] = row[i+1]
      end
    end
  end
end
print_table.call



puts
puts "char* codonTableSuite[] = {"
max_table_number = table_names.keys.max
(0..max_table_number).each do |num|
  if table_names[num]
    print table_names[num]
    print ',' unless num == max_table_number
    puts
  else
    puts "NULL,"
  end
end
puts "};"


puts
puts "int num_translation_tables = #{max_table_number};"
