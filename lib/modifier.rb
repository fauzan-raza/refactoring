require File.expand_path('lib/combiner',File.dirname(__FILE__))
require File.expand_path('lib/helper',File.dirname(__FILE__))
require 'csv'
require 'date'

class Modifier

	KEYWORD_UNIQUE_ID 		= 'Keyword Unique ID'
	LAST_VALUE_WINS 			= ['Account ID', 'Account Name', 'Campaign', 'Ad Group', 'Keyword', 'Keyword Type', 'Subid', 'Paused', 'Max CPC', 'Keyword Unique ID', 'ACCOUNT', 'CAMPAIGN', 'BRAND', 'BRAND+CATEGORY', 'ADGROUP', 'KEYWORD']
	LAST_REAL_VALUE_WINS 	= ['Last Avg CPC', 'Last Avg Pos']
	INT_VALUES						= ['Clicks', 'Impressions', 'ACCOUNT - Clicks', 'CAMPAIGN - Clicks', 'BRAND - Clicks', 'BRAND+CATEGORY - Clicks', 'ADGROUP - Clicks', 'KEYWORD - Clicks']
	FLOAT_VALUES 					= ['Avg CPC', 'CTR', 'Est EPC', 'newBid', 'Costs', 'Avg Pos']
	COMMISSION_VALUES 		= ['Commission Value', 'ACCOUNT - Commission Value', 'CAMPAIGN - Commission Value', 'BRAND - Commission Value', 'BRAND+CATEGORY - Commission Value', 'ADGROUP - Commission Value', 'KEYWORD - Commission Value']						
	NUM_OF_COMMISSIONS		= ['number of commissions']

  LINES_PER_FILE 				= 120000

  READ_CSV_OPTIONS 		  = { col_sep: "\t", headers: :first_row }
  WRITE_CSV_OPTIONS 		= { col_sep: "\t", headers: :first_row, row_sep: "\r\n" }

	def initialize(saleamount_factor, cancellation_factor)
		@saleamount_factor = saleamount_factor
		@cancellation_factor = cancellation_factor
	end

	def modify(output, input)
		input = sort(input)
		input_enumerator = lazy_read(input)

		combiner = Combiner.new do |value|
			value[KEYWORD_UNIQUE_ID]
		end.combine(input_enumerator)

		merger = Enumerator.new do |yielder|
			while true
				begin
					list_of_rows = combiner.next
					merged = combine_hashes(list_of_rows)
					yielder.yield(combine_values(merged))
				rescue StopIteration
					break
				end
			end
		end

    create_files(output, merger)

	end

	def create_files(output, merger)
		done 			 = false
    file_index = 0
    file_name  = output.gsub('.txt', '')
    
    while not done do
		  CSV.open(file_name + "_#{file_index}.txt", "wb", WRITE_CSV_OPTIONS) do |csv|
			  headers_written = false
        line_count 		  = 0
			  
			  unless headers_written
			  	merged = merger.next
				  csv << merged.keys
				  csv << merged
				  headers_written = true
          line_count +=2
				end
				 
				begin
			  	while line_count < LINES_PER_FILE
					  merged = merger.next
					  csv << merged
		        line_count +=1
		      end  
			  rescue StopIteration
          done = true
				  break
			  end

			end
        file_index += 1
    end
	end

	def sort(file)
		output 					 = "#{file}.sorted"
		content_as_table = parse(file)
		headers 				 = content_as_table.headers
		index_of_key 		 = headers.index('Clicks')
		content 				 = content_as_table.sort_by { |a| -a[index_of_key].to_i }
		write(content, headers, output)
		return output
	end

	private

	def combine(merged)
		result = []
		merged.each do |_, hash|
			result << combine_values(hash)
		end
		result
	end

	def combine_values(hash)
		LAST_VALUE_WINS.each do |key|
			hash[key] = hash[key].last
		end
		LAST_REAL_VALUE_WINS.each do |key|
			hash[key] = hash[key].select {|v| not (v.nil? or v == 0 or v == '0' or v == '')}.last
		end
		INT_VALUES.each do |key|
			hash[key] = hash[key][0].to_s
		end
		FLOAT_VALUES.each do |key|
			hash[key] = hash[key][0].from_german_to_f.to_german_s
		end
		NUM_OF_COMMISSIONS.each do |key|
			hash[key] = (@cancellation_factor * hash[key][0].from_german_to_f).to_german_s
		end
		COMMISSION_VALUES.each do |key|
			hash[key] = (@cancellation_factor * @saleamount_factor * hash[key][0].from_german_to_f).to_german_s
		end
		hash
	end

	def combine_hashes(list_of_rows)
		keys = []
		keys = list_of_rows.compact.map(&:headers)
		keys.flatten!

		result = {}
		keys.each do |key|
			result[key] = []
			result[key] = list_of_rows.map { |r| r.nil? ? nil : r[key]  }
		end
		result
	end

	def parse(file)
		CSV.read(file, READ_CSV_OPTIONS)
	end

	def lazy_read(file)
		Enumerator.new do |yielder|
			CSV.foreach(file, READ_CSV_OPTIONS) do |row|
				yielder.yield(row)
			end
		end
	end

	def write(content, headers, output)
		CSV.open(output, "wb", WRITE_CSV_OPTIONS) do |csv|
			csv << headers
			content.each do |row|
				csv << row
			end
		end
	end

end
