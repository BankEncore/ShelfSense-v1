# frozen_string_literal: true

module Pos
  class ReturnItemsController < BaseController
    before_action :load_original_transaction!

    def show
      prepare_return_items_view
    end

    def create
      target_session = cashier_target_session
      unless target_session
        @error = "Open a register before processing a return."
        prepare_return_items_view
        render :show, status: :unprocessable_entity
        return
      end

      working = Pos::ResumeOrStartTransaction.call(session: target_session, actor: current_user)
      Pos::AddLinkedReturnLines.call(
        transaction: working,
        actor: current_user,
        expected_lock_version: working.lock_version,
        items: selected_items
      )
      session[:pos_register_id] = target_session.register_id
      redirect_to pos_register_workspace_path(register_id: target_session.register_id)
    rescue Pos::Denied
      redirect_to root_path, alert: "You are not authorized to perform that action."
    rescue Pos::StaleObject
      @error = "This sale was changed. Reload and try again."
      prepare_return_items_view
      render :show, status: :unprocessable_entity
    rescue Pos::Error => e
      @error = e.message
      prepare_return_items_view
      render :show, status: :unprocessable_entity
    end

    private

    def load_original_transaction!
      @transaction = PosTransaction.completed.find_by!(id: params[:transaction_id], store_id: current_store.id)
    end

    def prepare_return_items_view
      @target_session = cashier_target_session
      @working_transaction = @target_session&.pos_transactions&.working&.first
      @sale_lines = @transaction.pos_transaction_lines.select(&:sale?)
      @summaries = Pos::Returnability.summary_for(@sale_lines)
      @basket_quantities = {}
      if @working_transaction
        @working_transaction.pos_transaction_lines.select(&:linked_return?).each do |line|
          @basket_quantities[line.original_transaction_line_id.to_s] = line.quantity
        end
      end
      @has_working_tenders = @working_transaction.present? && @working_transaction.pos_tenders.any?
      @can_add = @target_session.present? && @sale_lines.any? do |line|
        remaining = @summaries.fetch(line.id).remaining_quantity
        remaining.positive? && @basket_quantities[line.id.to_s].blank?
      end
      @reasons = Pos::ReturnReasons::ENTRIES
    end

    def selected_items
      rows = params[:items]
      raise Pos::Error, "return items are required" if rows.blank?

      selected = rows.each_value.filter_map do |row|
        attrs = row.respond_to?(:permit) ? row.permit(:selected, :original_line_id, :quantity, :reason_code, :reason_note) : row
        next unless ActiveModel::Type::Boolean.new.cast(attrs[:selected])

        {
          original_line_id: attrs[:original_line_id],
          quantity: attrs[:quantity],
          reason_code: attrs[:reason_code],
          reason_note: attrs[:reason_note]
        }
      end
      raise Pos::Error, "return items are required" if selected.empty?

      selected
    end
  end
end
