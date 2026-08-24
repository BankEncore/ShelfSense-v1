# frozen_string_literal: true

class AddProductSubjectAssignmentHeadingSchemeFk < ActiveRecord::Migration[8.1]
  def change
    add_index :subject_headings, [ :id, :subject_scheme_id ],
              unique: true, name: "index_subject_headings_id_and_scheme"
    add_foreign_key :product_subject_assignments, :subject_headings,
                    column: [ :subject_heading_id, :subject_scheme_id ],
                    primary_key: [ :id, :subject_scheme_id ],
                    name: "fk_product_subject_assignments_heading_scheme"
  end
end
