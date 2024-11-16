# frozen_string_literal: true

module ETL::Transformers::Async
  class HardrockHistoricalFactsStrategy < ETL::Transformers::BaseTransformer
    JUNK_PREVIOUS_NAMES = ["no", "n", "n/a", "na", "none"].freeze
    PRIOR_YEARS = (1992..2024).to_a.map { |year| year.to_s.to_sym }.freeze

    def initialize(parsed_structs, options)
      @parsed_structs = parsed_structs
      @options = options
      @import_job = options[:import_job]
      @proto_records = []
      @errors = []
    end

    def transform
      return [] if errors.present?

      parsed_structs.each.with_index(1) do |struct, row_index|
        set_base_proto_record(struct)
        record_dns_years(struct)
        record_volunteer_legacy(struct)
        record_2024_qualifier(struct)
        record_emergency_contact(struct)
        record_previous_names(struct)
      rescue StandardError => e
        import_job.increment!(:failed_count)
        errors << transform_failed_error(e, row_index)
      end

      proto_records
    end

    private

    attr_reader :parsed_structs, :options, :import_job, :proto_records
    attr_accessor :base_proto_record

    def set_base_proto_record(struct)
      self.base_proto_record = ProtoRecord.new(**struct.to_h)

      base_proto_record.transform_as(:historical_fact)
      base_proto_record.slice_permitted!
    end

    def record_dns_years(struct)
      dns_years = struct.to_h.slice(*PRIOR_YEARS).select { |_, val| val == "DNS" }.keys.map(&:to_s)

      dns_years.each do |year|
        proto_record = base_proto_record.deep_dup
        proto_record[:kind] = :dns
        proto_record[:comments] = year
        proto_records << proto_record
      end
    end

    def record_volunteer_legacy(struct)
      volunteer_legacy_count = struct[:Years_Volunteering]

      if volunteer_legacy_count.present? && volunteer_legacy_count.positive?
        proto_record = base_proto_record.deep_dup
        proto_record[:kind] = :volunteer_legacy
        proto_record[:quantity] = volunteer_legacy_count
        proto_record[:comments] = struct[:Description_of_service]
        proto_records << proto_record
      end
    end

    def record_2024_qualifier(struct)
      reported_qualifier = struct[:"2024_Qualifier"]

      if reported_qualifier.present?
        proto_record = base_proto_record.deep_dup
        proto_record[:kind] = :reported_qualifier_finish
        proto_record[:comments] = reported_qualifier
        proto_records << proto_record
      end
    end

    def record_emergency_contact(struct)
      emergency_contact = struct[:Emergency_Contact]
      emergency_phone = struct[:Emergency_Phone]

      if emergency_contact.present? || emergency_phone.present?
        proto_record = base_proto_record.deep_dup
        proto_record[:kind] = :provided_emergency_contact
        proto_record[:comments] = [emergency_contact.presence, emergency_phone.presence].compact.join(", ")
        proto_records << proto_record
      end
    end

    def record_previous_names(struct)
      previous_names = struct[:Previous_names_applied_under]

      if previous_names.present?
        return if previous_names.downcase.strip.in? JUNK_PREVIOUS_NAMES

        proto_record = base_proto_record.deep_dup
        proto_record[:kind] = :provided_previous_name
        proto_record[:comments] = previous_names
        proto_records << proto_record
      end
    end
  end
end
