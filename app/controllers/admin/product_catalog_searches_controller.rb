# frozen_string_literal: true

module Admin
  class ProductCatalogSearchesController < BaseController
    before_action -> { require_permission!("products.create") }

    def new
      @query = params[:q]
      @result = nil
    end

    def create
      @query = params.require(:catalog_search).permit(:q)[:q]
      @result = Bibliographic::Search.call(query: @query)
      if @result.status == :existing
        redirect_to admin_product_path(@result.existing_product), notice: "That identifier already belongs to this product."
        return
      end

      render :new, status: (@result.status == :invalid ? :unprocessable_entity : :ok)
    rescue ActionController::ParameterMissing
      @query = nil
      @result = Bibliographic::Search::Result.new(status: :invalid, message: "Enter an ISBN or title")
      render :new, status: :unprocessable_entity
    end
  end
end
