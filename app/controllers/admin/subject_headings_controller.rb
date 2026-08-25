# frozen_string_literal: true

module Admin
  class SubjectHeadingsController < BaseController
    before_action :set_subject_scheme
    before_action -> { require_permission!("subject_headings.view") }, only: %i[index show]
    before_action -> { require_permission!("subject_headings.create") }, only: %i[new create]
    before_action -> { require_permission!("subject_headings.update") }, only: %i[edit update]
    before_action -> { require_permission!("subject_headings.deactivate") }, only: %i[destroy reactivate]
    before_action -> { require_permission!("subject_headings.create") }, only: %i[import process_import]
    before_action -> { require_permission!("subject_headings.update") }, only: %i[process_import]
    before_action :set_subject_heading, only: %i[show edit update destroy reactivate]

    def index
      redirect_to admin_subject_scheme_path(@subject_scheme, q: params[:q])
    end

    def show; end

    def new
      @subject_heading = @subject_scheme.subject_headings.build(active: true)
      load_form_options
    end

    def create
      @subject_heading = @subject_scheme.subject_headings.build(subject_heading_params.except(:lock_version))
      if create_and_audit!(
        @subject_heading,
        action: "subject_headings.create",
        after_values: { code: @subject_heading.code, name: @subject_heading.name, scheme_key: @subject_scheme.key }
      )
        redirect_to admin_subject_scheme_subject_heading_path(@subject_scheme, @subject_heading),
                    notice: "Subject heading created."
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_options
    end

    def update
      rescue_stale do
        if save_and_audit!(
          @subject_heading,
          attrs: subject_heading_params,
          action: "subject_headings.update",
          before_keys: %w[code name display_order suggested_merchandise_class_id active]
        )
          redirect_to admin_subject_scheme_subject_heading_path(@subject_scheme, @subject_heading),
                      notice: "Subject heading updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@subject_heading, action: "subject_headings.deactivate") do
        @subject_heading.update!(active: false)
      end
      redirect_to admin_subject_scheme_path(@subject_scheme), notice: "Subject heading deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @subject_heading,
        permission_key: "subject_headings.deactivate",
        audit_action: "subject_headings.reactivate",
        redirect_path: admin_subject_scheme_subject_heading_path(@subject_scheme, @subject_heading)
      )
    end

    def import; end

    def process_import
      result = SubjectHeadings::Import.call(
        scheme: @subject_scheme,
        csv_text: import_csv_text,
        actor: current_user
      )
      redirect_to admin_subject_scheme_path(@subject_scheme),
                  notice: "Imported headings (#{result.created} created, #{result.updated} updated)."
    rescue SubjectHeadings::Import::Error => e
      @import_error = e.message
      render :import, status: :unprocessable_entity
    end

    private

    def set_subject_scheme
      @subject_scheme = SubjectScheme.find(params[:subject_scheme_id])
    end

    def set_subject_heading
      @subject_heading = @subject_scheme.subject_headings.find(params[:id])
    end

    def load_form_options
      @merchandise_classes = MerchandiseClass.assignable.admin_ordered
      if @subject_heading&.suggested_merchandise_class &&
         @merchandise_classes.exclude?(@subject_heading.suggested_merchandise_class)
        @merchandise_classes = [ @subject_heading.suggested_merchandise_class ] + @merchandise_classes.to_a
      end
    end

    def subject_heading_params
      permitted = params.require(:subject_heading).permit(
        :code, :name, :display_order, :suggested_merchandise_class_id, :lock_version
      )
      %i[code display_order suggested_merchandise_class_id].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end

    def import_csv_text
      file = params[:csv]
      return file.read if file.respond_to?(:read)

      params[:csv_text].to_s
    end
  end
end
