# frozen_string_literal: true

module Admin
  class MerchandiseImportsController < BaseController
    before_action -> { require_permission!("merchandise.import") }

    def new; end

    def create
      upload = params.require(:import).permit(:file)[:file]
      if upload.blank?
        flash.now[:alert] = "CSV file is required."
        render :new, status: :unprocessable_entity
        return
      end

      result = Merchandise::CsvImporter.call(io: upload, actor: current_user)
      Audit::Recorder.record!(
        action: "merchandise.import",
        outcome: result.errors.any? ? "succeeded_with_errors" : "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        after_values: {
          created_products: result.created_products,
          updated_products: result.updated_products,
          created_variants: result.created_variants,
          updated_variants: result.updated_variants,
          error_count: result.errors.size
        }
      )
      @result = result
      render :new
    rescue ActionController::ParameterMissing
      flash.now[:alert] = "CSV file is required."
      render :new, status: :unprocessable_entity
    rescue Merchandise::CsvImporter::Error => e
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end
  end
end
