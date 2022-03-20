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
    game = self::Game.new
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

    def hangman_states
      [empty_hangman,
       complete_hangman.first(3) + empty_hangman.last(5),
       complete_hangman.first(6).map { |row| row.tr("\/\\", '  ') } + empty_hangman.last(2),
       complete_hangman.first(6).map { |row| row.tr("\\", ' ') } + empty_hangman.last(2),
       complete_hangman.first(6) + empty_hangman.last(2),
       complete_hangman.map.with_index { |row, i| i == 6 ? row.tr("\\", ' ') : row },
       complete_hangman]
        #use method with lambda/function call for these??
    end
  end

  class Game
    include Hangman::Visual

    def initialize
      puts(hangman_states.map { |state| state.join("\r\n") })
      @word = Hangman.words.sample
      @correct_guessed, @incorrect_guessed = []
      puts "Let's play Hangman! The computer has selected a word for you to guess."
      puts 'Press ENTER to continue.'
      gets
    end

    def display_game_status
    end
  end
end

Hangman.run
