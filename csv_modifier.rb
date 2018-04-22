require File.expand_path('lib/modifier',File.dirname(__FILE__))

def latest(name)
  files = Dir["#{ ENV["HOME"] }/workspace/*#{ name }*.txt"]

  files.sort_by! do |file|
    last_date = /\d+-\d+-\d+_[[:alpha:]]+\.txt$/.match file
    last_date = last_date.to_s.match /\d+-\d+-\d+/

    DateTime.parse(last_date.to_s)
  end

  throw RuntimeError if files.empty?

  files.last
end

modification_factor = 1
cancellaction_factor = 0.4
modified = input = latest('project_2012-07-27_2012-10-10_performancedata')
modifier = Modifier.new(modification_factor, cancellaction_factor)
modifier.modify(modified, input)

puts "DONE modifying"