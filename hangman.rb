require_relative 'input_validation'

module Hangman
  @min_length = 5
  @max_length = 12
  @words = File.readlines('google-10000-english-no-swears.txt')
               .map(&:chomp)
               .select { |word| word.length.between?(@min_length, @max_length) }

  class << self
    attr_reader :words
  end

  def self.run
    loop do
      puts 'Start a new game? Y/N'
      unless /^yes|y$/i =~ gets.chomp
        puts 'Okay, bye!'
        break
      end
      self::Game.new.play
    end
  end

  module Visual
    def complete_hangman
      ['   ___',
       '  |  _|_',
       '  | |___|',
       '  |   |',
       "  |  \/|\\",
       '  |   |',
       "  |  \/ \\",
       '__|__']
    end

    def empty_hangman
      complete_hangman.map.with_index do |row, i|
        next row unless i.between?(1, 6)
        next row.tr('_', ' ') if i == 1

        row[0..2]
      end
    end

    def constructed_hangman(complete_rows, &complete_row_map)
      complete_row_map ||= ->(row, _i) { row }
      complete_hangman.first(complete_rows).map.with_index(&complete_row_map) + empty_hangman.last(8 - complete_rows)
    end

    def hangman_states
      [constructed_hangman(0),
       constructed_hangman(3),
       constructed_hangman(6) { |row| row.tr("\/\\", '  ') },
       constructed_hangman(6) { |row| row.tr("\\", ' ') },
       constructed_hangman(6),
       constructed_hangman(8) { |row, i| i == 6 ? row.tr("\\", ' ') : row },
       constructed_hangman(8)]
    end

    def hangman_string(hangman_state)
      hangman_state.map { |row| ' ' * 8 + row }.join("\r\n")
    end
  end

  module LetterValidation
    include InputValidation

    def unused_letter_input
      letter = letter_input
      while (@correct_guessed + @incorrect_guessed).include?(letter)
        puts "You have already guessed #{letter.upcase}. Please guess a different letter."
        letter = letter_input
      end
      letter
    end
  end

  class Game
    include Hangman::Visual
    include Hangman::LetterValidation

    def initialize
      @word = Hangman.words.sample
      @correct_guessed = []
      @incorrect_guessed = []
      puts "Let's play Hangman! The computer has selected a word for you to guess."
      puts "You can guess a total of #{hangman_states.size - 1} incorrect letters before you lose."
      puts 'Press ENTER to continue.'
      gets
    end

    def play
      until @game_over
        display_game_status
        guess_letter
        check_game_over
      end
    end

    def display_game_status
      incorrect_guesses = @incorrect_guessed.size
      puts hangman_string(hangman_states[incorrect_guesses])
      puts "\r\n"
      puts "Word: #{correct_letters_in_word}"
      puts "\r\n"
      puts "Incorrect letters: #{@incorrect_guessed.join(', ')} (#{incorrect_guesses}/6)"
      puts "\r\n"
    end

    def correct_letters_in_word
      @word.chars.map { |letter| @correct_guessed.include?(letter) ? letter : '_' }.join(' ')
    end

    def guess_letter
      puts 'Please type a letter to guess the letter.'
      letter = unused_letter_input
      if @word.include?(letter.downcase)
        @correct_guessed << letter.downcase
        puts "Yes, the word has #{letter.upcase}."
      else
        @incorrect_guessed << letter.downcase
        puts "No, the word doesn't have #{letter.upcase}."
      end
    end

    def check_game_over
      won = @word.chars.all? { |letter| @correct_guessed.include?(letter) }
      lost = @incorrect_guessed.size == 6
      return unless won || lost

      display_game_status
      puts "#{won ? 'Congratulations, you won!' : 'Sorry, you ran out of guesses.'} The word was \"#{@word}\"."
      @game_over = true
    end
  end
end

Hangman.run
