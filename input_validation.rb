module InputValidation
  def letter_input
    input = gets.chomp
    until /[A-Za-z]/ =~ input
      puts 'Please enter one (1) single letter.'
      input = gets.chomp
    end
    input
  end
end
