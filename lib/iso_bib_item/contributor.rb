# frozen_string_literal: true

require 'uri'

module IsoBibItem
  # Contact method.
  class ContactMethod
    # @return [String] @todo TBD
    attr_reader :contact
  end

  # Affilation.
  class Affilation
    # @return [IsoBibItem::LocalizedString]
    attr_reader :name

    # @return [Array<IsoBibItem::FormattedString>]
    attr_reader :description

    # @return [IsoBibItem::Organization]
    attr_reader :organization

    # @param organization [IsoBibItem::Organization]
    def initialize(organization)
      @organization = organization
      @description  = []
    end
  end

  # Contributor.
  class Contributor
    # @return [URI]
    attr_reader :uri

    # @return [Array<IsoBibItem::ContactMethod>]
    attr_reader :contacts

    # @param url [String]
    def initialize(url = nil)
      @uri = URI url if url
      @contacts = []
    end

    # @return [String]
    def url
      @uri.to_s
    end

    def to_xml(builder)
      contacts.each { |contact| contact.to_xml builder }
    end
  end
end
