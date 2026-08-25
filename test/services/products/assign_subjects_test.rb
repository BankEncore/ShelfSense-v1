# frozen_string_literal: true

require "test_helper"

class Products::AssignSubjectsTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    SubjectSchemes::Catalog.seed!
    @bisac = SubjectScheme.find_by!(key: "bisac")
    @house = SubjectScheme.find_by!(key: "house")
    @fiction = @bisac.subject_headings.create!(code: "FIC000000", name: "Fiction", active: true)
    @mystery = @bisac.subject_headings.create!(code: "FIC022000", name: "Mystery", active: true)
    @local = @house.subject_headings.create!(name: "Staff pick", active: true)
    @product = Products::Create.call(attributes: { name: "Subjected", status: "draft" }, actor: @actor)
  end

  test "heading search matches code or name" do
    assert_includes SubjectHeading.search("FIC022").map(&:id), @mystery.id
    assert_includes SubjectHeading.search("staff").map(&:id), @local.id
  end

  test "allows one primary per scheme and rejects duplicates" do
    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: @product.lock_version,
        subject_rows: [
          { "subject_heading_id" => @fiction.id, "primary" => true },
          { "subject_heading_id" => @mystery.id, "primary" => false },
          { "subject_heading_id" => @local.id, "primary" => true }
        ]
      },
      actor: @actor
    )
    @product.reload
    assert_equal 3, @product.product_subject_assignments.count
    assert_equal 1, @product.product_subject_assignments.where(subject_scheme: @bisac, primary: true).count

    error = assert_raises(Products::Update::Error) do
      Products::Update.call(
        product: @product,
        attributes: {
          lock_version: @product.lock_version,
          subject_rows: [
            { "subject_heading_id" => @fiction.id, "primary" => true },
            { "subject_heading_id" => @mystery.id, "primary" => true }
          ]
        },
        actor: @actor
      )
    end
    assert_match(/primary/i, error.message)
  end

  test "inactive headings cannot be newly assigned but remain on the product" do
    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: @product.lock_version,
        subject_rows: [ { "subject_heading_id" => @fiction.id, "primary" => true } ]
      },
      actor: @actor
    )
    @fiction.update!(active: false)
    @product.reload
    assert_equal @fiction.id, @product.product_subject_assignments.first.subject_heading_id

    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: @product.lock_version,
        subject_rows: [ { "subject_heading_id" => @fiction.id, "primary" => true } ]
      },
      actor: @actor
    )
    @product.reload
    assert_equal @fiction.id, @product.product_subject_assignments.first.subject_heading_id

    @mystery.update!(active: false)
    error = assert_raises(Products::Update::Error) do
      Products::Update.call(
        product: @product,
        attributes: {
          lock_version: @product.lock_version,
          subject_rows: [
            { "subject_heading_id" => @fiction.id, "primary" => true },
            { "subject_heading_id" => @mystery.id, "primary" => false }
          ]
        },
        actor: @actor
      )
    end
    assert_match(/active heading/i, error.message)
  end

  test "suggested class is prefill only and does not reclassify variants" do
    klass = MerchandiseClass.assignable.first
    skip "no merchandise class fixture" unless klass

    variant_class_id = @product.product_variants.first&.merchandise_class_id
    @fiction.update!(suggested_merchandise_class: klass)
    @fiction.update!(suggested_merchandise_class: nil)
    @product.reload
    assert_equal variant_class_id, @product.product_variants.first&.merchandise_class_id
  end

  test "bulk import is atomic" do
    csv = <<~CSV
      code,name,display_order
      FIC000000,Fiction updated,10
      BAD
    CSV
    assert_raises(SubjectHeadings::Import::Error) do
      SubjectHeadings::Import.call(scheme: @bisac, csv_text: csv, actor: @actor)
    end
    assert_equal "Fiction", @fiction.reload.name
  end

  test "product concurrency and subjects provenance" do
    stale = @product.lock_version
    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: stale,
        subject_rows: [ { "subject_heading_id" => @fiction.id, "primary" => true } ]
      },
      actor: @actor
    )
    assert_equal "staff", @product.reload.bibliographic_field_sources.dig("subjects", "source")

    assert_raises(ActiveRecord::StaleObjectError) do
      Products::Update.call(
        product: @product.reload,
        attributes: {
          lock_version: stale,
          subject_rows: [ { "subject_heading_id" => @mystery.id, "primary" => true } ]
        },
        actor: @actor
      )
    end
  end

  test "checkbox-style primary params persist false and true without null" do
    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: @product.lock_version,
        subject_rows: [ { "subject_heading_id" => @fiction.id } ]
      },
      actor: @actor
    )
    assignment = @product.reload.product_subject_assignments.find_by!(subject_heading: @fiction)
    assert_equal false, assignment.primary

    Products::Update.call(
      product: @product,
      attributes: {
        lock_version: @product.lock_version,
        subject_rows: [ { "subject_heading_id" => @fiction.id, "primary" => "1" } ]
      },
      actor: @actor
    )
    assert_equal true, assignment.reload.primary
  end

  test "generic provider subject text does not attach a BISAC heading by name" do
    house_fiction = @house.subject_headings.create!(name: "Fiction", active: true)

    assert_equal [ house_fiction.id ], Bibliographic::SubjectMatcher.call([ "Fiction" ]).map(&:id)
    assert_equal [ @fiction.id ], Bibliographic::SubjectMatcher.call([ "FIC000000" ]).map(&:id)
  end

  test "assignment scheme must match the heading scheme" do
    assignment = @product.product_subject_assignments.build(
      subject_heading: @fiction,
      subject_scheme: @house,
      position: 0
    )
    assert_not assignment.valid?
    assert_includes assignment.errors[:subject_scheme_id].join, "match"

    assignment.subject_scheme = @fiction.subject_scheme
    assert assignment.valid?
  end
end
