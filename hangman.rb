require 'yaml'

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
    options = ['NEW (Start a new game)', 'LOAD (Load a game)', 'EXIT (Exit the program)']
    puts "\r\nMAIN MENU: What would you like to do? Type one of the following commands."
    puts "\r\n#{options.map { |opt| "  -#{opt}" }.join("\r\n")}"
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

  module SaveLoadSystem
    # TODO: Add a 'DELETE (Delete saved games)' option to main menu
    module Shared
      def save_dir
        "#{File.dirname(__FILE__)}/saves"
      end

      def save_record
        "#{File.dirname(__FILE__)}/save_record.txt"
      end

      def valid_save_name(max_length)
        name = gets.chomp
        reg = Regexp.new("^\\w{1,#{max_length}}|go back$", true)
        until reg =~ name
          puts 'Please enter at least one character.' if name.empty?
          puts "Please enter a string of at most #{max_length} characters." if name.length > max_length
          puts 'Please enter a string consisting of letters/numbers only.' if /[^\w]/ =~ name
          name = gets.chomp
        end
        return if name.downcase == 'go back'

        name
      end

      def name_record_reg(name)
        Regexp.new("^#{name} (.*)$", true)
      end

      def update_save_record(name, add)
        new_record = File.readlines(save_record)
        new_record.reject! { |prior_save| name_record_reg(name) =~ prior_save }
        new_record << "#{name.downcase} (#{correct_letters_in_word})" if add
        File.open(save_record, 'w') do |record|
          new_record.each { |save| record.puts(save) }
        end
      end

      def display_saved_games
        puts 'SAVED GAMES:'
        puts "\r\n"
        File.readlines(save_record).each do |save|
          puts "  -#{save}"
        end
        puts "\r\n"
      end
    end

    module Save
      def save_game
        Dir.mkdir(save_dir) unless Dir.exist?(save_dir)
        return unless (name = save_name)

        update_save_record(name, true)
        File.open(save_dir + "/#{name}.yaml", 'w') { |yaml_file| to_yaml(yaml_file) }
        puts "Game \"#{name}\" successfully saved!"

        offer_game_exit
      end

      def save_name
        Dir.glob("#{save_dir}/*").size < 20 ? new_save_name : overwrite_name
      end

      def new_save_name
        loop do
          puts 'Type "GO BACK" to resume your game without saving.'
          puts 'Please type a name for your save file (max 15 characters, letters and numbers only, no spaces).'
          return unless (name = valid_save_name(15))
          return name unless name_record_reg(name) =~ File.read(save_record)

          puts 'You already have a saved game with this name. Do you want to overwrite your previous save? Y/N'
          return name if /^yes|y$/i =~ gets.chomp
        end
      end

      def overwrite_name
        display_saved_games
        puts 'Your save files are full.'
        loop do
          puts 'Please type the name of one of the above existing save files to overwrite, ' \
               'or type "GO BACK" to resume your game without saving.'
          return unless (name = valid_save_name(15))

          existing_save_game = name_record_reg(name) =~ File.read(save_record)
          return name if existing_save_game && /^yes|y$/i =~ overwrite_name_confirm(name)
          return if !existing_save_game && /^yes|y|go back$/i =~ overwrite_name_resume
        end
      end

      def overwrite_name_confirm(name)
        puts "Overwrite the save file \"#{name}\"? Y/N"
        gets.chomp
      end

      def overwrite_name_resume
        puts 'There is no save file with that name. Resume game without saving? Y/N'
        gets.chomp
      end

      def offer_game_exit
        puts 'Exit to main menu? Y/N'
        @game_over = true if /^yes|y|exit$/i =~ gets.chomp
      end
    end

    module Load
      def load_game
        if !Dir.exist?(save_dir) || Dir.empty?(save_dir)
          puts 'Sorry, you have no saved games. Press RETURN to exit to main menu.'
          gets
          return @game_over = true
        end

        display_saved_games
        name = load_name
        return @game_over = true unless name

        from_yaml(save_dir + "/#{name}.yaml")
        puts "Game \"#{name}\" successfully loaded!"
      end

      def load_name
        loop do
          puts 'Type "GO BACK" if you wish to exit to main menu.'
          puts 'Please type the name of the game you wish to load.'
          return unless (name = valid_save_name(15))
          return name if name_record_reg(name) =~ File.read(save_record)

          puts 'There is no saved game with that name. Exit to main menu? Y/N'
          return if /^yes|y|go back$/i =~ gets.chomp
        end
      end
    end

    module Delete
      def delete_game(name)
        update_save_record(name, false)
        File.delete(save_dir + "/#{name}.yaml")
      end
    end
  end

  class Game
    include Hangman::Visual
    include Hangman::GameInputValidation
    include Hangman::SaveLoadSystem::Shared
    include Hangman::SaveLoadSystem::Save
    include Hangman::SaveLoadSystem::Load
    include Hangman::SaveLoadSystem::Delete

    def initialize(new_game)
      new_game ? start_new_game : load_game
      return if @game_over

      puts 'Press the RETURN key to begin playing.'
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
      until @game_over
        display_game_status
        next_move
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

    def next_move
      puts 'Type "SAVE" to save your game or "EXIT" to exit to main menu.'
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
      puts 'Press the RETURN key to exit to main menu.'
      gets
      @game_over = true
    end
  end
end

Hangman.run
