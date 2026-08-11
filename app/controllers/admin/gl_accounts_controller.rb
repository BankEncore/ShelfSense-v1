# frozen_string_literal: true

module Admin
  class GlAccountsController < BaseController
    before_action -> { require_permission!("gl_accounts.view") }, only: %i[index show]
    before_action -> { require_permission!("gl_accounts.create") }, only: %i[new create]
    before_action -> { require_permission!("gl_accounts.update") }, only: %i[edit update]
    before_action -> { require_permission!("gl_accounts.deactivate") }, only: %i[destroy reactivate]
    before_action :set_gl_account, only: %i[show edit update destroy reactivate]

    def index
      @gl_accounts = GlAccount.order(:display_order, :account_number)
    end

    def show; end

    def new
      @gl_account = GlAccount.new(posting_allowed: true, display_order: 0)
      load_parent_options
    end

    def create
      @gl_account = GlAccount.new(gl_account_params.except(:lock_version, :account_type))
      if create_and_audit!(
        @gl_account,
        action: "gl_accounts.create",
        after_values: {
          account_number: @gl_account.account_number,
          name: @gl_account.name,
          account_type: @gl_account.account_type,
          account_category: @gl_account.account_category
        }
      )
        redirect_to admin_gl_account_path(@gl_account), notice: "GL account created."
      else
        load_parent_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_parent_options
    end

    def update
      rescue_stale do
        if save_and_audit!(
          @gl_account,
          attrs: gl_account_params.except(:account_type),
          action: "gl_accounts.update",
          before_keys: %w[
            account_number name description account_type account_category
            parent_id posting_allowed display_order
          ]
        )
          redirect_to admin_gl_account_path(@gl_account), notice: "GL account updated."
        else
          load_parent_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@gl_account, action: "gl_accounts.deactivate") { @gl_account.update!(active: false) }
      redirect_to admin_gl_accounts_path, notice: "GL account deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @gl_account,
        permission_key: "gl_accounts.deactivate",
        audit_action: "gl_accounts.reactivate",
        redirect_path: admin_gl_account_path(@gl_account)
      )
    end

    private

    def set_gl_account
      @gl_account = GlAccount.find(params[:id])
    end

    def load_parent_options
      scope = GlAccount.order(:account_number)
      scope = scope.where.not(id: @gl_account.id) if @gl_account&.persisted?
      @parent_options = scope
    end

    def gl_account_params
      permitted = params.require(:gl_account).permit(
        :account_number, :name, :description, :account_category,
        :parent_id, :posting_allowed, :display_order, :lock_version
      )
      permitted[:parent_id] = nil if permitted[:parent_id].blank?
      permitted
    end
  end
end
