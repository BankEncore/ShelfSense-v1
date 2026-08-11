# frozen_string_literal: true

class NormalizePhase21MachineCodes < ActiveRecord::Migration[8.1]
  TABLES = {
    "tax_classes" => { nullable: false },
    "departments" => { nullable: false },
    "merchandise_classes" => { nullable: false },
    "merchandise_conditions" => { nullable: false },
    "merchandise_categories" => { nullable: true }
  }.freeze

  def up
    TABLES.each do |table, opts|
      rows = connection.select_all("SELECT id, code FROM #{table} WHERE code IS NOT NULL")
      collisions = Hash.new { |h, k| h[k] = [] }

      rows.each do |row|
        normalized = normalize_code(row["code"])
        if normalized.blank?
          raise ActiveRecord::IrreversibleMigration,
                "#{table} id=#{row["id"]} code=#{row["code"].inspect} normalizes to blank"
        end
        collisions[normalized] << row["id"]
      end

      dupes = collisions.select { |_, ids| ids.size > 1 }
      if dupes.any?
        report = dupes.map { |code, ids| "#{code}: #{ids.join(", ")}" }.join("; ")
        raise ActiveRecord::IrreversibleMigration,
              "Normalized code collisions in #{table}: #{report}"
      end

      rows.each do |row|
        normalized = normalize_code(row["code"])
        next if normalized == row["code"]

        connection.execute(
          sanitize("UPDATE #{table} SET code = ?, updated_at = ? WHERE id = ?",
                   normalized, Time.current, row["id"])
        )
      end

      if opts[:nullable]
        add_check_constraint table,
                             "code IS NULL OR code ~ '^[a-z0-9]+(_[a-z0-9]+)*$'",
                             name: "#{table}_code_format"
      else
        add_check_constraint table,
                             "code ~ '^[a-z0-9]+(_[a-z0-9]+)*$'",
                             name: "#{table}_code_format"
      end
    end
  end

  def down
    TABLES.each_key do |table|
      remove_check_constraint table, name: "#{table}_code_format", if_exists: true
    end
  end

  private

  def normalize_code(raw)
    value = ActiveSupport::Inflector.transliterate(raw.to_s)
    value = value.downcase
    value = value.gsub(/[^a-z0-9]+/, "_")
    value = value.gsub(/\A_+|_+\z/, "")
    value.gsub(/_+/, "_")
  end

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([ sql, *binds ])
  end
end
