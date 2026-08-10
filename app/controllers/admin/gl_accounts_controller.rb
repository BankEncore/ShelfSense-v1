# frozen_string_literal: true

module Admin
  class GlAccountsController < BaseController
    before_action -> { require_permission!("gl_accounts.view") }, only: %i[index show]
    before_action -> { require_permission!("gl_accounts.create") }, only: %i[new create]
    before_action -> { require_permission!("gl_accounts.update") }, only: %i[edit update]
    before_action -> { require_permission!("gl_accounts.deactivate") }, only: :destroy
    before_action :set_gl_account, only: %i[show edit update destroy]

    def index
      @gl_accounts = GlAccount.order(:display_order, :account_number)
    end

    def show; end

    def new
      @gl_account = GlAccount.new(posting_allowed: true, display_order: 0)
      load_parent_options
    end

    def create
      @gl_account = GlAccount.new(gl_account_params.except(:lock_version))
      if @gl_account.save
        Audit::Recorder.record!(
          action: "gl_accounts.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @gl_account,
          after_values: {
            account_number: @gl_account.account_number,
            name: @gl_account.name,
            account_type: @gl_account.account_type
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
        before = @gl_account.attributes.slice(
          "account_number", "name", "description", "account_type", "account_category",
          "parent_id", "posting_allowed", "display_order"
        )
        if @gl_account.update(gl_account_params)
          Audit::Recorder.record!(
            action: "gl_accounts.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @gl_account,
            before_values: before,
            after_values: @gl_account.attributes.slice(*before.keys)
          )
          redirect_to admin_gl_account_path(@gl_account), notice: "GL account updated."
        else
          load_parent_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @gl_account.update!(active: false)
      Audit::Recorder.record!(
        action: "gl_accounts.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        subject: @gl_account
      )
      redirect_to admin_gl_accounts_path, notice: "GL account deactivated."
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
        :account_number, :name, :description, :account_type, :account_category,
        :parent_id, :posting_allowed, :display_order, :lock_version
      )
      permitted[:parent_id] = nil if permitted[:parent_id].blank?
      permitted
    end
  end
end
