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

  class Game
    def initialize
      @word = Hangman.words.sample
      @correct_guessed, @incorrect_guessed = []
      puts "Let's play Hangman! The computer has selected a word for you to guess."
      puts 'Press ENTER to continue.'
      gets
    end
  end
end

Hangman.run
