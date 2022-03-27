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
      option = select_program_option
      if option.downcase == 'exit'
        puts 'Okay, bye!'
        break
      end
      self::Game.new(option.downcase == 'new').play
    end
  end

  def self.select_program_option
    options = "\r\n#{['NEW (Start a new game)', 'LOAD (Load a game)', 'EXIT (Exit the program)'].join("\r\n")}"
    puts 'What would you like to do? Type one of the following commands.'
    puts options
    option = gets.chomp
    until /^new|load|exit$/i =~ option
      puts 'Please type NEW, LOAD, or EXIT.'
      puts options
      option = gets.chomp
    end
    option
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
    def next_move_input
      loop do
        input = gets.chomp
        return input if /^save|exit$/i =~ input ||
                        /^[A-Za-z]$/i =~ input && !guessed(input)

        puts 'Please type one (1) single letter to guess the letter. (Or type SAVE or EXIT.)' if input.length > 1
        if /^[A-Za-z]$/i =~ input && guessed(input)
          puts "You have already guessed #{input.upcase}. Please guess a different letter."
        end
      end
    end

    def guessed(input)
      (@correct_guessed + @incorrect_guessed).include?(input)
    end
  end

  module SaveSystem
    include InputValidation
    # TODO: Implement a limit for number of save files and a way to delete save files
    def save_dir
      "#{File.dirname(__FILE__)}/saves"
    end

    def save_record
      "#{File.dirname(__FILE__)}/save_record.txt"
    end

    def offer_game_save
      puts 'Type "SAVE" if you wish to save your game. Press ENTER to continue.'
      return unless /^save$/i =~ gets.chomp

      save_game
    end

    def save_game
      Dir.mkdir(save_dir) unless Dir.exist?(save_dir)

      name = save_name
      update_save_record(name)
      File.open(save_dir + "/#{name}.yaml", 'w') { |yaml_file| to_yaml(yaml_file) }
      puts "Game \"#{name}\" successfully saved!"

      offer_game_exit
    end

    def save_name
      loop do
        puts 'Please type a name for your save file (max 15 characters, letters and numbers only, no spaces).'
        name = alphanumeric_input(15)
        return name unless name_record_reg(name) =~ File.read(save_record)

        puts 'You already have a saved game with this name. Do you want to overwrite your previous save? Y/N'
        return name if /^yes|y$/i =~ gets.chomp
      end
    end

    def name_record_reg(name)
      Regexp.new("^#{name} (.*)$", true)
    end

    def update_save_record(name)
      new_record = File.readlines(save_record)
      new_record.reject! { |prior_save| name_record_reg(name) =~ prior_save }
      new_record << "#{name} (#{correct_letters_in_word})"
      File.open(save_record, 'w') do |record|
        new_record.each { |save| record.puts(save) }
      end
    end

    def offer_game_exit
      puts 'Exit your current game? Y/N'
      @game_over = true if /^yes|y$/i =~ gets.chomp
    end

    def load_game
      # TODO: More robust way to check if there are no save files - maybe check if save_dir exists AND if it's not empty
      return 'Sorry, you have no saved games.' unless File.exist?(save_record)

      display_save_files
      name = load_name
      return unless name

      from_yaml(save_dir + "/#{name}.yaml")
      puts "Game \"#{name}\" successfully loaded!"
    end

    def display_save_files
      puts 'SAVED GAMES:'
      puts "\r\n"
      File.readlines(save_record).each do |save|
        puts "  -#{save}"
      end
      puts "\r\n"
    end

    def load_name
      loop do
        puts 'Please type the name of the game you wish to load.'
        name = alphanumeric_input(15)
        return name if name_record_reg(name) =~ File.read(save_record)

        puts 'There is no saved game with that name. Do you wish to start a new game? Y/N'
        return start_new_game if /^yes|y$/i =~ gets.chomp
      end
    end
  end

  class Game
    include Hangman::Visual
    include Hangman::GameInputValidation
    include Hangman::SaveSystem

    def initialize(new_game)
      new_game ? start_new_game : load_game
      puts 'Press ENTER to continue.'
      gets
    end

    def start_new_game
      @word = Hangman.words.sample
      @correct_guessed = []
      @incorrect_guessed = []
      puts "Let's play Hangman! The computer has selected a word for you to guess."
      puts "You can guess a total of #{hangman_states.size - 1} incorrect letters before you lose."
    end

    def to_yaml(file)
      YAML.dump({ word: @word, correct_guessed: @correct_guessed, incorrect_guessed: @incorrect_guessed }, file)
    end

    def from_yaml(file)
      data = YAML.load_file(file)
      @word = data[:word]
      @correct_guessed = data[:correct_guessed]
      @incorrect_guessed = data[:incorrect_guessed]
    end

    def play
      loop do
        display_game_status
        next_move
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

    def next_move
      puts 'Type "SAVE" to save your game or "EXIT" to exit your game.'
      puts 'Please type a letter to guess the letter.'

      move = next_move_input
      return save_game if move.downcase == 'save'
      return offer_game_exit if move.downcase == 'exit'

      guess_letter(move)
    end

    def guess_letter(letter)
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
      puts 'Press ENTER to continue.'
      gets
      @game_over = true
    end
  end
end

Hangman.run
