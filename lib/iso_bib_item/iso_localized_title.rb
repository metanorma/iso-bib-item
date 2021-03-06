# frozen_string_literal: true

module IsoBibItem
  # ISO localized string.
  class IsoLocalizedTitle
    # @return [String]
    attr_reader :title_intro

    # @return [String]
    attr_reader :title_main

    # @return [String]
    attr_reader :title_part

    # @return [String] language code Iso639
    attr_reader :language

    # @return [String] script code Iso15924
    attr_reader :script

    # @param title_intro [String]
    # @param title_main [String]
    # @param title_part [String]
    # @param language [String] language Iso639 code
    # @param script [String] script Iso15924 code
    def initialize(title_intro:, title_main:, title_part: nil, language:,
                   script:)
      @title_intro = title_intro
      @title_main  = title_main
      @title_part  = title_part
      @language    = language
      @script      = script
      @title_main = '[ -- ]' if @title_main.nil? || @title_main.empty?
      # "[ -- ]" # title cannot be nil
    end

    def remove_part
      @title_part = nil
    end

    # @return [String]
    def to_s
      ret = @title_main
      ret = "#{@title_intro} -- #{ret}" if @title_intro && !@title_intro.empty?
      ret = "#{ret} -- #{@title_part}" if @title_part && !@title_part.empty?
      ret
    end

    def to_xml(builder)
      builder.title(format: 'text/plain', language: language, script: script) do
        builder.text to_s
      end
    end
  end
end
