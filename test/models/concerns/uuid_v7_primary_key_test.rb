# frozen_string_literal: true

require "test_helper"

class UuidV7PrimaryKeyTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :uuid_v7_test_records, id: :uuid, default: nil, force: true do |t|
      t.string :name, null: false
      t.uuid :parent_id
      t.timestamps
    end

    @model = Class.new(ApplicationRecord) do
      self.table_name = "uuid_v7_test_records"

      validates :name, presence: true
      belongs_to :parent, class_name: name, optional: true
      has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify

      def self.name
        "UuidV7TestRecord"
      end
    end
  end

  teardown do
    @connection.drop_table :uuid_v7_test_records, if_exists: true
  end

  test "assigns uuid v7 before validation completes" do
    record = @model.new(name: "alpha")
    assert_nil record.id

    record.valid?

    assert record.id.present?
    assert_equal 7, uuid_version(record.id)
    assert_equal 0b10, uuid_variant(record.id)
  end

  test "preserves an explicitly supplied uuid v7" do
    explicit = SecureRandom.uuid_v7
    record = @model.new(id: explicit, name: "beta")
    record.valid?

    assert_equal explicit, record.id
  end

  test "rejects invalid uuid text" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @model.transaction(requires_new: true) do
        @model.insert_all([ { id: "not-a-uuid", name: "bad", created_at: Time.current, updated_at: Time.current } ])
      end
    end
  end

  test "callback-bypassing insertion without id fails clearly" do
    error = assert_raises(ActiveRecord::NotNullViolation, ActiveRecord::StatementInvalid) do
      @model.transaction(requires_new: true) do
        @model.insert_all([ { name: "missing-id", created_at: Time.current, updated_at: Time.current } ])
      end
    end

    assert_match(/null value in column "id"|NotNullViolation/i, "#{error.class}: #{error.message}")
  end

  test "insert_all succeeds when given an explicit uuid v7" do
    id = SecureRandom.uuid_v7
    assert_nothing_raised do
      @model.insert_all([ { id: id, name: "bulk", created_at: Time.current, updated_at: Time.current } ])
    end

    assert_equal "bulk", @model.find(id).name
    assert_equal 7, uuid_version(id)
  end

  test "parent and child uuid relationships work before saving" do
    parent = @model.new(name: "parent")
    parent.valid?
    child = @model.new(name: "child", parent_id: parent.id)
    child.valid?

    assert parent.id.present?
    assert_equal parent.id, child.parent_id
  end

  private

  def uuid_version(uuid)
    uuid.to_s.delete("-")[12].to_i(16)
  end

  def uuid_variant(uuid)
    (uuid.to_s.delete("-")[16].to_i(16) & 0b1100) >> 2
  end
end
