# frozen_string_literal: false

require 'nokogiri'
require 'isoics'
require 'deep_clone'
require 'iso_bib_item/bibliographic_item'
require 'iso_bib_item/iso_document_status'
require 'iso_bib_item/iso_localized_title'
require 'iso_bib_item/iso_project_group'
require 'iso_bib_item/document_relation_collection'
require 'iso_bib_item/xml_parser'

# Add filter method to Array.
class Array
  def filter(type:)
    select { |e| e.type == type }
  end
end

module IsoBibItem
  # Iso document id.
  class IsoDocumentId
    # @return [Integer]
    attr_reader :tc_document_number

    # @return [String]
    attr_reader :project_number

    # @return [String]
    attr_reader :part_number

    # @return [String]
    attr_reader :subpart_number

    # @return [String]
    attr_reader :id

    # @return [String]
    attr_reader :prefix

    # @return [String]
    attr_reader :type

    # @param project_number [String]
    # @param part_number [String]
    # @param subpart_number [String]
    # @param prefix [String]
    # @param id [String]
    # @param type [String]
    def initialize(**args)
      @project_number = args[:project_number]
      @part_number    = args[:part_number]
      @subpart_number = args[:subpart_number]
      @prefix         = args[:prefix]
      @type           = args[:type]
      @id             = args[:id]
    end

    # in docid manipulations, assume ISO as the default: id-part:year
    def remove_part
      @part_number = nil
      @subpart_number = nil
      case @type
      when "Chinese Standard" then @id = @id.sub(/\.\d+/, "")
      else 
        @id = @id.sub(/-\d+/, "")
      end
    end

    def remove_date
      case @type
      when "Chinese Standard" then @id = @id.sub(/-[12]\d\d\d/, "")
      else
        @id = @id.sub(/:[12]\d\d\d/, "")
      end
    end

    def all_parts
      @id = @id + " (all parts)"
    end

    def to_xml(builder)
      attrs = {}
      attrs[:type] = @type if @type
      # builder.docidentifier project_number + '-' + part_number, **attrs
      builder.docidentifier id, **attrs
    end
  end

  # module IsoDocumentType
  #   INTERNATIONAL_STANDART           = "internationalStandard"
  #   TECHNICAL_SPECIFICATION          = "techinicalSpecification"
  #   TECHNICAL_REPORT                 = "technicalReport"
  #   PUPLICLY_AVAILABLE_SPECIFICATION = "publiclyAvailableSpecification"
  #   INTERNATIONAL_WORKSHOP_AGREEMENT = "internationalWorkshopAgreement"
  # end

  # Iso ICS classificator.
  class Ics < Isoics::ICS
    # @param field [Integer]
    # @param group [Integer]
    # @param subgroup [Integer]
    def initialize(code = nil, field: nil, group: nil, subgroup: nil)
      unless code || field
        raise ArgumentError, "wrong arguments (should be string or { fieldcode: [String] }"
      end

      field, group, subgroup = code.split '.' if code
      super fieldcode: field, groupcode: group, subgroupcode: subgroup
    end

    def to_xml(builder)
      builder.ics do
        builder.code code
        builder.text_ description
      end
    end
  end

  # rubocop:disable Metrics/ClassLength

  # Bibliographic item.
  class IsoBibliographicItem < BibliographicItem
    # @return [Array<IsoBibItem::IsoDocumentId>]
    attr_reader :docidentifier

    # @return [String]
    attr_reader :edition

    # @!attribute [r] title
    #   @return [Array<IsoBibItem::IsoLocalizedTitle>]

    # @return [IsoBibItem::IsoDocumentType]
    attr_reader :type

    # @return [IsoBibItem::IsoDocumentStatus]
    attr_reader :status

    # @return [IsoBibItem::IsoProjectGroup]
    attr_reader :workgroup

    # @return [Array<IsoBibItem::Ics>]
    attr_reader :ics

    # @param docid [Hash{project_number=>Integer, part_number=>Integer, prefix=>string},
    #   IsoBibItem::IsoDocumentId]
    # @param titles [Array<Hash{title_intro=>String, title_main=>String,
    #   title_part=>String, language=>String, script=>String}>]
    # @param edition [String]
    # @param language [Array<String>]
    # @param script [Arrra<String>]
    # @param type [String]
    # @param docstatus [Hash{status=>String, stage=>String, substage=>String}]
    # @param workgroup [Hash{name=>String, abbreviation=>String, url=>String,
    #   technical_committee=>Hash{name=>String, type=>String, number=>Integer}}]
    # @param ics [Array<Hash{field=>Integer, group=>Integer,
    #   subgroup=>Integer}>]
    # @param dates [Array<Hash{type=>String, from=>String, to=>String}>]
    # @param abstract [Array<Hash{content=>String, language=>String,
    #   script=>String, type=>String}>]
    # @param contributors [Array<Hash{entity=>Hash{name=>String, url=>String,
    #   abbreviation=>String}, roles=>Array<String>}>]
    # @param copyright [Hash{owner=>Hash{name=>String, abbreviation=>String,
    #   url=>String}, form=>String, to=>String}]
    # @param link [Array<Hash{type=>String, content=>String}, IsoBibItem::TypedUri>]
    # @param relations [Array<Hash{type=>String, identifier=>String}>]
    def initialize(**args)
      super_args = args.select do |k|
        %i[
          id language script dates abstract contributors relations copyright link
        ].include? k
      end
      super(super_args)
      args[:docid] = [args[:docid]] unless args[:docid].is_a?(Array)
      @docidentifier = args[:docid].map do |t|
        t.is_a?(Hash) ? IsoDocumentId.new(t) : t
      end
      @edition = args[:edition]
      @title   = args[:titles].map do |t|
        t.is_a?(Hash) ? IsoLocalizedTitle.new(t) : t
      end
      @type   = args[:type]
      @status = if args[:docstatus].is_a?(Hash)
                  IsoDocumentStatus.new(args[:docstatus])
                else args[:docstatus] end
      if args[:workgroup]
        @workgroup = if args[:workgroup].is_a?(Hash)
                       IsoProjectGroup.new(args[:workgroup])
                     else args[:workgroup] end
      end
      @ics = args[:ics].map { |i| i.is_a?(Hash) ? Ics.new(i) : i }
      @link = args[:link].map { |s| s.is_a?(Hash) ? TypedUri.new(s) : s }
      @id_attribute = true
    end

    def disable_id_attribute
      @id_attribute = false
    end

    # remove title part components and abstract  
    def to_all_parts
      me = DeepClone.clone(self)
      me.disable_id_attribute
      @relations << DocumentRelation.new(type: "partOf", identifier: nil, url: nil, bibitem: me)
      @title.each(&:remove_part)
      @abstract = []
      @docidentifier.each(&:remove_part)
      @docidentifier.each(&:all_parts)
      @all_parts = true
    end

    # convert ISO:yyyy reference to reference to most recent
    # instance of reference, removing date-specific infomration:
    # date of publication, abstracts. Make dated reference Instance relation
    # of the redacated document
    def to_most_recent_reference
      me = DeepClone.clone(self)
      me.disable_id_attribute
      @relations << DocumentRelation.new(type: "instance", identifier: nil, url: nil, bibitem: me)
      @abstract = []
      @dates = []
      @docidentifier.each(&:remove_date)
    end

    # @param lang [String] language code Iso639
    # @return [IsoBibItem::IsoLocalizedTitle]
    def title(lang: nil)
      if lang
        @title.find { |t| t.language == lang }
      else
        @title
      end
    end

    # @param type [Symbol] type of url, can be :src/:obp/:rss
    # @return [String]
    def url(type = :src)
      @link.find { |s| s.type == type.to_s }.content.to_s
    end

    # @return [String]
    def to_xml(builder = nil, **opts, &block)
      if builder
        render_xml builder, opts, &block
      else
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          render_xml xml, opts, &block
        end.doc.root.to_xml
      end
    end

    private

    # @return [Array<IsoBibItem::ContributionInfo>]
    # def publishers
    #   @contributors.select do |c|
    #     c.role.select { |r| r.type == 'publisher' }.any?
    #   end
    # end

    def makeid(id, attribute, delim = '')
      return nil if attribute && !@id_attribute
      id = @docidentifier.reject { |i| i.type == "DOI" }[0] unless id
      #contribs = publishers.map { |p| p&.entity&.abbreviation }.join '/'
      #idstr = "#{contribs}#{delim}#{id.project_number}"
      #idstr = id.project_number.to_s
      idstr = id.id.gsub(/:/, "-")
      idstr = "IEV" if id.project_number == "IEV"
      #if id.part_number&.size&.positive? then idstr += "-#{id.part_number}"
      idstr.strip
    end

    def xml_attrs(type)
      attrs = { type: type }
      attr_id = makeid(nil, true)&.gsub(/ /, "")
      attrs[:id] = attr_id if attr_id
      attrs
    end

    def render_xml(builder, **opts)
      builder.send(:bibitem, xml_attrs(type)) do
        builder.fetched fetched
        title.each { |t| t.to_xml builder }
        link.each { |s| s.to_xml builder }
        docidentifier.each { |i| i.to_xml builder }
        dates.each { |d| d.to_xml builder, opts }
        contributors.each do |c|
          builder.contributor do
            c.role.each { |r| r.to_xml builder }
            c.to_xml builder
          end
        end
        builder.edition edition if edition
        language.each { |l| builder.language l }
        script.each { |s| builder.script s }
        abstract.each { |a| builder.abstract { a.to_xml(builder) } }
        status.to_xml builder
        copyright.to_xml builder if copyright
        relations.each { |r| r.to_xml builder }
        workgroup.to_xml builder if workgroup
        if opts[:note]
          builder.note("ISO DATE: #{opts[:note]}", format: 'text/plain')
        end
        ics.each { |i| i.to_xml builder }
        builder.allparts 'true' if @all_parts
        yield(builder) if block_given?
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
