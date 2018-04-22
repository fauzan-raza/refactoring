modification_factor = 1
cancellaction_factor = 0.4
modified = input = latest('project_2012-07-27_2012-10-10_performancedata')
modifier = Modifier.new(modification_factor, cancellaction_factor)
modifier.modify(modified, input)

puts "DONE modifying"