# frozen_string_literal: true

module Admin
  class SubjectSchemesController < BaseController
    before_action -> { require_permission!("subject_schemes.view") }, only: %i[index show]
    before_action -> { require_permission!("subject_schemes.update") }, only: %i[edit update]
    before_action :set_subject_scheme, only: %i[show edit update]

    def index
      @subject_schemes = SubjectScheme.admin_ordered
    end

    def show
      @subject_headings = @subject_scheme.subject_headings.admin_ordered
      @subject_headings = @subject_headings.search(params[:q]) if params[:q].present?
    end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @subject_scheme,
          attrs: subject_scheme_params.except(:key),
          action: "subject_schemes.update",
          before_keys: %w[name active scheme_version]
        )
          redirect_to admin_subject_scheme_path(@subject_scheme), notice: "Subject scheme updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    private

    def set_subject_scheme
      @subject_scheme = SubjectScheme.find(params[:id])
    end

    def subject_scheme_params
      permitted = params.require(:subject_scheme).permit(:key, :name, :scheme_version, :active, :lock_version)
      permitted[:active] = ActiveModel::Type::Boolean.new.cast(permitted[:active]) if permitted.key?(:active)
      permitted
    end
  end
end
