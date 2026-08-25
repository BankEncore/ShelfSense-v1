# frozen_string_literal: true

module ProductForms
  module BindingMigrator
    module_function

    Mapped = Struct.new(:id, :binding, :code, :legacy, keyword_init: true)

    def classify(id:, binding:)
      text = binding.to_s
      code = Bibliographic::ProductFormMapper.code_for(text)
      Mapped.new(id: id, binding: text, code: code, legacy: code.blank?)
    end
  end
end
