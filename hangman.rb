require 'yaml'
require_relative 'input_validation'

module Hangman
  @min_length = 5
  @max_length = 12
  @words = File.readlines("#{File.dirname(__FILE__)}/google-10000-english-no-swears.txt")
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

  module GameInputValidation
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

  module SaveSystem
    # TODO: Make load game methods
    # TODO: Implement a limit for number of save files and a way to delete save files
    def offer_game_save
      puts 'Type "SAVE" if you wish to save your game. Press ENTER to continue.'
      return unless /^save$/i =~ gets.chomp

      save_game
    end

    def save_game
      Dir.mkdir("#{File.dirname(__FILE__)}/saves") unless Dir.exist?("#{File.dirname(__FILE__)}/saves")
      file_names = File.open("#{File.dirname(__FILE__)}/save_record.txt", 'a+')
      name = save_name(file_names)
      file_names.puts "#{name}: #{correct_letters_in_word}"
      file_names.close
      File.open("#{File.dirname(__FILE__)}/saves/#{name}.yaml", 'w') { |yaml_file| to_yaml(yaml_file) }
      puts "Game \"#{name}\" successfully saved!"

      offer_game_exit
    end

    def save_name(file_names)
      name = 'defaultsave'
      loop do
        puts 'Please type a name for your save file (at most 15 characters, letters and numbers only, no spaces).'
        name = alphanumeric_input(15)
        name_reg = Regexp.new("#{name}:", true)
        break unless name_reg =~ file_names.read

        puts 'You already have a saved game with this name. Do you want to overwrite your previous save? Y/N'
        break if /^yes|y$/i =~ gets.chomp
      end
      name
    end

    def offer_game_exit
      puts 'Exit your current game? Y/N'
      @game_over = true if /^yes|y$/i =~ gets.chomp
    end
  end

  class Game
    include Hangman::Visual
    include Hangman::GameInputValidation
    include Hangman::SaveSystem

    def initialize
      @word = Hangman.words.sample
      @correct_guessed = []
      @incorrect_guessed = []
      puts "Let's play Hangman! The computer has selected a word for you to guess."
      puts "You can guess a total of #{hangman_states.size - 1} incorrect letters before you lose."
      puts 'Press ENTER to continue.'
      gets
    end

    def to_yaml(file)
      YAML.dump({ word: @word, correct_guessed: @correct_guessed, incorrect_guessed: @incorrect_guessed }, file)
    end

    def play
      # TO DO: Make save option a bit more streamlined/natural for UI
      # by allowing player to either guess a single letter or type the word 'SAVE'
      loop do
        display_game_status
        offer_game_save
        break if @game_over

        guess_letter
        check_game_over
        break if @game_over
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
