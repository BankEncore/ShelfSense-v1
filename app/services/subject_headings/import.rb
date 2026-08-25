# frozen_string_literal: true

require "csv"

module SubjectHeadings
  class Import
    class Error < StandardError; end

    Result = Struct.new(:created, :updated, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(scheme:, csv_text:, actor:)
      @scheme = scheme
      @csv_text = csv_text.to_s
      @actor = actor
    end

    def call
      rows = parse_rows
      raise Error, "import is empty" if rows.empty?

      created = 0
      updated = 0
      SubjectHeading.transaction do
        rows.each do |row|
          heading = find_heading(row)
          if heading
            heading.assign_attributes(row.except("code"))
            heading.save!
            updated += 1
          else
            SubjectHeading.create!(row.merge("subject_scheme" => @scheme))
            created += 1
          end
        end

        Audit::Recorder.record!(
          action: "subject_headings.import",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          subject: @scheme,
          after_values: { scheme_key: @scheme.key, created: created, updated: updated, row_count: rows.size }
        )
      end
      Result.new(created: created, updated: updated)
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      raise Error, e.message
    end

    private

    def parse_rows
      table = CSV.parse(@csv_text, headers: true, skip_blanks: true)
      raise Error, "CSV must include a header row" if table.headers.blank?

      table.map.with_index(2) { |row, line|
        data = row.to_h.transform_keys { |key| key.to_s.strip.downcase }
        name = data["name"].to_s.strip
        raise Error, "name is required on line #{line}" if name.blank?

        attrs = {
          "name" => name,
          "code" => data["code"].to_s.strip.presence,
          "display_order" => parse_integer(data["display_order"]),
          "suggested_merchandise_class_id" => class_id_for(data, line)
        }
        if @scheme.key == "bisac" && attrs["code"].blank?
          raise Error, "BISAC headings require a code on line #{line}"
        end
        attrs
      }
    rescue CSV::MalformedCSVError => e
      raise Error, e.message
    end

    def find_heading(row)
      if row["code"].present?
        @scheme.subject_headings.find_by(code: row["code"])
      else
        @scheme.subject_headings.find_by(code: nil, name: row["name"])
      end
    end

    def parse_integer(raw)
      return if raw.blank?

      Integer(raw)
    rescue ArgumentError
      raise Error, "display_order must be an integer"
    end

    def class_id_for(data, line)
      raw = data["suggested_merchandise_class_id"].presence || data["suggested_merchandise_class_code"].presence
      return if raw.blank?

      klass =
        if raw.match?(/\A[0-9a-f-]{36}\z/i)
          MerchandiseClass.find_by(id: raw)
        else
          MerchandiseClass.find_by(code: raw.to_s.strip.downcase)
        end
      raise Error, "unknown merchandise class on line #{line}" if klass.nil?
      raise Error, "suggested merchandise class must be active on line #{line}" unless klass.assignable?

      klass.id
    end
  end
end
