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
