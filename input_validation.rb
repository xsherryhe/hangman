module InputValidation
  def letter_input
    input = gets.chomp
    until /^[A-Za-z]$/ =~ input
      puts 'Please enter one (1) single letter.'
      input = gets.chomp
    end
    input
  end

  def alphanumeric_input(max_length)
    input = gets.chomp
    reg = Regexp.new("^\\w{1,#{max_length}}$")
    until reg =~ input
      puts 'Please enter at least one character.' if input.empty?
      puts "Please enter a string of at most #{max_length} characters." if input.length > 15
      puts 'Please enter a string consisting of letters/numbers only.' if /[^\w]/ =~ input
      input = gets.chomp
    end
    input
  end
end
