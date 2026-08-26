# frozen_string_literal: true

module Admin
  class GiftCardProgramsController < BaseController
    before_action -> { require_permission!("gift_cards.manage_programs") }
    before_action :set_program, only: %i[show edit update destroy reactivate]

    def index
      @programs = GiftCardProgram.admin_ordered
    end

    def show; end

    def new
      @program = GiftCardProgram.new(
        number_authority: "system_generated",
        number_length: GiftCardProgram::PHASE10_NUMBER_LENGTH,
        check_digit_algorithm: "luhn",
        cash_out_policy: "permitted_when_eligible",
        reload_allowed: true
      )
    end

    def create
      @program = GiftCardProgram.new(program_params)
      if create_and_audit!(@program, action: "gift_cards.programs.create", after_values: { code: @program.code, prefix: @program.prefix })
        redirect_to admin_gift_card_program_path(@program), notice: "Gift-card program created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @program,
          attrs: program_params.except(:code),
          action: "gift_cards.programs.update",
          before_keys: %w[name active reload_allowed cash_out_policy cash_out_approval_required]
        )
          redirect_to admin_gift_card_program_path(@program), notice: "Gift-card program updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@program, action: "gift_cards.programs.deactivate") { @program.update!(active: false) }
      redirect_to admin_gift_card_programs_path, notice: "Gift-card program deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @program,
        permission_key: "gift_cards.manage_programs",
        audit_action: "gift_cards.programs.reactivate",
        redirect_path: admin_gift_card_program_path(@program)
      )
    end

    private

    def set_program
      @program = GiftCardProgram.find(params[:id])
    end

    def program_params
      params.require(:gift_card_program).permit(
        :code, :name, :number_authority, :prefix, :number_length, :check_digit_algorithm,
        :reload_allowed, :minimum_activation_cents, :maximum_balance_cents, :cash_out_policy,
        :cash_out_threshold_cents, :cash_out_threshold_inclusive, :cash_out_approval_required,
        :lock_version
      )
    end
  end
end
