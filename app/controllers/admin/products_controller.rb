# frozen_string_literal: true

module Admin
  class ProductsController < BaseController
    include PurchasingHelper

    before_action -> { require_permission!("products.view") }, only: %i[index show]
    before_action -> { require_permission!("products.create") }, only: %i[new create]
    before_action -> { require_permission!("products.update") }, only: %i[edit update bibliographic_review apply_bibliography refresh_bibliography]
    before_action -> { require_permission!("products.discontinue") }, only: %i[discontinue reactivate]
    before_action -> { require_permission!("products.update") }, only: :destroy
    before_action :set_product, only: %i[show edit update destroy discontinue reactivate bibliographic_review apply_bibliography refresh_bibliography]

    def index
      @index = Products::AdminIndexQuery.call(
        q: params[:q],
        status: params[:status],
        merchandise_category_id: params[:merchandise_category_id],
        page: params[:page]
      )
      @products = @index.records.includes(:merchandise_category)
      @variant_counts = ProductVariant.where(product_id: @products.map(&:id)).group(:product_id).count
      @merchandise_categories = MerchandiseCategory.assignable.admin_ordered
      @show_inventory = inventory_display_enabled?
      @on_hand_by_product_id = load_product_on_hand_totals(@products.map(&:id)) if @show_inventory
    end

    def show
      @product_variants = @product.product_variants
        .includes(:merchandise_class, :merchandise_condition, :tax_class_override, merchandise_class: [ :department, :default_tax_class ])
        .order(:sku)
      @recent_audit_events = recent_product_audit_events
      @show_inventory = inventory_display_enabled?
      if @show_inventory
        variant_ids = @product_variants.map(&:id)
        @balances_by_variant_id = load_variant_balances(variant_ids)
        @on_order_by_variant_id = load_variant_on_order_quantities(variant_ids)
        @on_hand_by_type = Hash.new(0)
        @on_order_by_type = { "standard" => 0, "used" => 0 }
        @product_variants.each do |variant|
          @on_hand_by_type[variant.variant_type] += @balances_by_variant_id[variant.id]&.on_hand_quantity.to_i
          next unless variant.standard?

          @on_order_by_type["standard"] += @on_order_by_variant_id[variant.id].to_i
        end
      end
      load_product_purchasing_actions
    end

    def new
      @product = Product.new(status: "draft")
      @candidate = Bibliographic::CandidateLoader.call(
        candidate_id: params[:candidate_id],
        isbn13: params[:isbn13],
        lookup_key: params[:lookup_key]
      )
      if @candidate
        apply_candidate_to_product(@product, @candidate)
        @possible_matches = Bibliographic::PossibleMatches.call(candidate: @candidate)
      end
      load_form_options
    end

    def create
      attrs = product_attributes
      if @money_error
        @product = Product.new(attrs)
        @product.errors.add(:list_price, @money_error)
        load_form_options
        render :new, status: :unprocessable_entity
        return
      end

      candidate = Bibliographic::CandidateLoader.call(
        candidate_id: params[:candidate_id],
        isbn13: params[:candidate_isbn13],
        lookup_key: params[:candidate_lookup_key]
      )
      if params[:candidate_id].present? && candidate.blank?
        @product = Product.new(attrs)
        @product.errors.add(:base, "That bibliographic candidate expired. Search again.")
        load_form_options
        render :new, status: :unprocessable_entity
        return
      end

      if candidate
        matches = Bibliographic::PossibleMatches.call(candidate: candidate)
        if (matches.strong.any? || matches.weak.any?) && params[:confirm_create_separately] != "1"
          @product = Product.new(attrs)
          @candidate = candidate
          @possible_matches = matches
          @product.errors.add(:base, "Review possible matches and confirm to create a separate product.")
          load_form_options
          render :new, status: :unprocessable_entity
          return
        end
      end

      @product =
        if candidate
          Products::CreateFromCandidate.call(
            candidate: candidate,
            actor: current_user,
            attributes: attrs.merge(
              contribution_rows: contribution_rows_from_params,
              subject_rows: subject_rows_from_params,
              cover_image: attrs[:cover_image]
            )
          )
        else
          Products::Create.call(
            attributes: attrs.except(:industry_identifier, :lookup_code, :cover_image).merge(
              contribution_rows: contribution_rows_from_params,
              subject_rows: subject_rows_from_params,
              cover_image: attrs[:cover_image]
            ),
            actor: current_user,
            industry_identifier: attrs[:industry_identifier],
            lookup_code: attrs[:lookup_code]
          )
        end
      redirect_to admin_product_path(@product), notice: "Product created."
    rescue Products::Create::Error, Products::CreateFromCandidate::Error => e
      @product = Product.new(attrs)
      @candidate = candidate
      @possible_matches = Bibliographic::PossibleMatches.call(candidate: candidate) if candidate
      @product.errors.add(:base, e.message)
      load_form_options
      render :new, status: :unprocessable_entity
    end

    def edit
      load_form_options
    end

    def update
      rescue_stale do
        attrs = product_params
        if @money_error
          render_form_with_money_error(:edit)
          return
        end

        if attrs[:status] == "discontinued"
          @product.errors.add(:status, "use Discontinue instead")
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        if @product.status == "discontinued" && attrs[:status].present? && attrs[:status] != "discontinued"
          @product.errors.add(:status, "use Reactivate instead")
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        begin
          Products::Update.call(
            product: @product,
            attributes: attrs.to_h.symbolize_keys.merge(
              contribution_rows: contribution_rows_from_params,
              subject_rows: subject_rows_from_params,
              cover_image: attrs[:cover_image]
            ),
            actor: current_user,
            store: current_store
          )
          redirect_to admin_product_path(@product), notice: "Product updated."
        rescue Products::Update::Error => e
          @product.errors.add(:base, e.message)
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def discontinue
      rescue_stale do
        before_status = @product.status
        mutate_and_audit!(
          @product,
          action: "products.discontinue",
          before_values: { status: before_status },
          after_values: { status: "discontinued" }
        ) { @product.update!(status: "discontinued") }
        redirect_to admin_product_path(@product), notice: "Product discontinued."
      end
    end

    def reactivate
      rescue_stale do
        unless @product.status == "discontinued"
          redirect_to admin_product_path(@product), alert: "Only discontinued products can be reactivated."
          return
        end

        if @product.merchandise_category.present? && !@product.merchandise_category.assignable?
          redirect_to admin_product_path(@product),
                      alert: "Cannot reactivate: merchandise category must be active."
          return
        end

        before_status = @product.status
        mutate_and_audit!(
          @product,
          action: "products.reactivate",
          before_values: { status: before_status },
          after_values: { status: "active" }
        ) { @product.update!(status: "active") }
        redirect_to admin_product_path(@product), notice: "Product reactivated."
      end
    end

    def bibliographic_review
      @candidate = load_review_candidate
      if @candidate.blank?
        redirect_to admin_product_path(@product), alert: "That bibliographic candidate expired. Search again."
        return
      end
      @review_fields = bibliographic_review_fields(@product, @candidate)
    end

    def apply_bibliography
      rescue_stale do
        candidate = Bibliographic::CandidateLoader.call(candidate_id: params[:candidate_id])
        if candidate.blank?
          redirect_to admin_product_path(@product), alert: "That bibliographic candidate expired. Search again."
          return
        end

        selected = Array(params[:selected_fields])
        @candidate = candidate
        submitted = review_submitted_values(selected)
        Bibliographic::ApplyCandidate.call(
          product: @product,
          candidate: candidate,
          actor: current_user,
          selected_fields: selected,
          submitted_values: submitted,
          lock_version: params.dig(:product, :lock_version) || params[:lock_version],
          store: current_store
        )
        redirect_to admin_product_path(@product), notice: "Bibliographic data applied."
      end
    rescue Bibliographic::ApplyCandidate::Error, ActiveRecord::StaleObjectError => e
      @candidate = Bibliographic::CandidateLoader.call(candidate_id: params[:candidate_id])
      @product.errors.add(:base, e.message)
      @review_fields = bibliographic_review_fields(@product, @candidate) if @candidate
      render :bibliographic_review, status: :unprocessable_entity
    end

    def refresh_bibliography
      isbn = @product.industry_identifier.presence || @product.bibliographic_provider_key
      if isbn.blank?
        redirect_to admin_product_path(@product), alert: "Add an industry identifier before refreshing bibliographic data."
        return
      end

      result = Bibliographic::Search.call(query: isbn, skip_local: true)
      candidate = Array(result.candidates).find { |row| row.isbn13 == isbn } || result.candidates&.first
      if candidate.blank?
        redirect_to admin_product_path(@product), alert: result.message.presence || "No bibliographic data found."
        return
      end

      redirect_to bibliographic_review_admin_product_path(@product, candidate_id: candidate.candidate_id)
    end

    def destroy
      unless @product.draft?
        redirect_to admin_product_path(@product), alert: "Only draft products can be deleted."
        return
      end

      primary_identifier = @product.primary_identifier
      industry_identifier = @product.industry_identifier
      name = @product.name
      Product.transaction do
        Identifiers::Registry.retire!(value: primary_identifier)
        Identifiers::Registry.retire!(value: industry_identifier) if industry_identifier.present?
        @product.destroy!
        Audit::Recorder.record!(
          action: "products.destroy",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          after_values: {
            primary_identifier: primary_identifier,
            industry_identifier: industry_identifier,
            name: name
          }
        )
      end
      redirect_to admin_products_path, notice: "Draft product deleted."
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotFound,
           ActiveRecord::StatementInvalid => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    private

    def set_product
      @product = Product.includes(:product_contributions, :product_form, product_subject_assignments: :subject_heading).find(params[:id])
    end

    def load_form_options
      @merchandise_categories = MerchandiseCategory.assignable.admin_ordered
      @product_forms = product_form_options_for(@product)
      @subject_headings = SubjectHeading.assignable.admin_ordered.includes(:subject_scheme)
    end

    def recent_product_audit_events
      return [] unless effective_permissions.include?("audit_events.view")

      scope = AuditEvent.where(subject_type: "Product", subject_id: @product.id)
      global_view = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "audit_events.view",
        store: nil
      )
      unless global_view
        scope = scope.where(store_id: accessible_stores.select(:id))
      end
      scope.order(occurred_at: :desc).limit(5).to_a
    end

    def product_attributes
      attrs = product_params.except(:lock_version).to_h.symbolize_keys
      attrs[:status] = "draft" if attrs[:status].blank?
      attrs
    end

    def product_params
      @money_error = nil
      @list_price_raw = params.dig(:product, :list_price)
      permitted = params.require(:product).permit(
        :name, :subtitle, :description, :brand_name, :product_model, :merchandise_category_id,
        :list_price, :list_price_cents, :release_date, :release_date_approximate, :status,
        :variant_option_name_1, :variant_option_name_2, :industry_identifier, :lookup_code,
        :lock_version, :imprint, :language_code, :page_count, :series_name,
        :series_position, :product_form_id, :cover_image,
        contribution_rows: [ :display_name, :role ],
        subject_rows: [ :subject_heading_id, :primary ]
      )

      if permitted.key?(:list_price) || params[:product]&.key?(:list_price)
        raw = permitted.delete(:list_price)
        raw = params.dig(:product, :list_price) if raw.nil?
        begin
          permitted[:list_price_cents] = Money::ParseCents.call(raw)
        rescue Money::ParseCents::Error => e
          @money_error = e.message
          permitted.delete(:list_price_cents)
        end
      end

      submitted = params[:product] || {}
      %i[merchandise_category_id list_price_cents release_date subtitle description brand_name
         product_model variant_option_name_1 variant_option_name_2 industry_identifier
         lookup_code imprint language_code page_count series_name series_position product_form_id].each do |key|
        next unless submitted.key?(key) || submitted.key?(key.to_s)

        permitted[key] = nil if permitted[key].blank?
      end
      permitted[:page_count] = permitted[:page_count].to_i if permitted[:page_count].present?
      permitted[:series_position] = permitted[:series_position] if permitted[:series_position].present?
      if submitted.key?(:release_date_approximate) || submitted.key?("release_date_approximate")
        permitted[:release_date_approximate] = ActiveModel::Type::Boolean.new.cast(permitted[:release_date_approximate]) == true
      else
        permitted.delete(:release_date_approximate)
      end
      permitted
    end

    def contribution_rows_from_params
      rows = params.dig(:product, :contribution_rows)
      return [] if rows.blank?

      list =
        if rows.is_a?(Array)
          rows
        else
          hash = rows.respond_to?(:to_unsafe_h) ? rows.to_unsafe_h : rows.to_h
          if hash.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
            hash.sort_by { |key, _| key.to_i }.map(&:last)
          else
            [ hash ]
          end
        end

      list.map { |row|
        data = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
        data.stringify_keys.slice("display_name", "role")
      }
    end

    def subject_rows_from_params
      rows = params.dig(:product, :subject_rows)
      return [] if rows.blank?

      list =
        if rows.is_a?(Array)
          rows
        else
          hash = rows.respond_to?(:to_unsafe_h) ? rows.to_unsafe_h : rows.to_h
          if hash.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
            hash.sort_by { |key, _| key.to_i }.map(&:last)
          else
            [ hash ]
          end
        end

      list.filter_map { |row|
        data = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
        sliced = data.stringify_keys.slice("subject_heading_id", "primary")
        next if sliced["subject_heading_id"].blank?

        sliced
      }
    end

    def apply_candidate_to_product(product, candidate)
      product.assign_attributes(candidate.product_attributes)
      product.industry_identifier = candidate.isbn13
      product.contribution_rows = candidate.contribution_rows
    end

    def load_review_candidate
      Bibliographic::CandidateLoader.call(
        candidate_id: params[:candidate_id],
        isbn13: @product.industry_identifier,
        lookup_key: @product.industry_identifier.present? ? "isbn:#{@product.industry_identifier}" : nil
      )
    end

    def bibliographic_review_fields(product, candidate)
      rows = [
        [ "name", "Title", product.name, candidate.title ],
        [ "subtitle", "Subtitle", product.subtitle, candidate.subtitle ],
        [ "description", "Description", product.description, candidate.description ],
        [ "brand_name", "Publisher", product.brand_name, candidate.publisher_name ],
        [ "imprint", "Imprint", product.imprint, candidate.imprint ],
        [ "product_model", "Edition / model", product.product_model, candidate.edition ],
        [ "language_code", "Language", product.language_code, candidate.language_code ],
        [ "page_count", "Pages", product.page_count, candidate.page_count ],
        [ "series_name", "Series", product.series_name, candidate.series_name ],
        [ "series_position", "Series position", product.series_position, candidate.series_position ],
        [ "release_date", "Release date", product.release_date, candidate.release_date ],
        [ "list_price_cents", "List price", format_review_money(product.list_price_cents), format_review_money(candidate.list_price_cents) ],
        [ "industry_identifier", "Industry identifier", product.industry_identifier, candidate.isbn13 ],
        [ "product_form", "Product form", product.product_form&.name, product_form_name_for(candidate.product_form_code), candidate.product_form_code ],
        [ "cover_image", "Cover image", product.cover_image.attached? ? "Attached" : nil, candidate.cover_image_url ],
        [ "subjects", "Subjects", product.subject_headings.map(&:name).join(", "), Bibliographic::SubjectMatcher.call(candidate.subjects).map(&:name).join(", ") ]
      ]
      rows.map { |key, label, current, proposed, extra|
        populated = current.present? || (key == "contributions" && product.product_contributions.any?)
        { key: key, label: label, current: current, proposed: proposed, proposed_code: extra, default_apply: !populated }
      } + [
        {
          key: "contributions",
          label: "Contributors",
          current: product.product_contributions.map { |row| "#{row.display_name} (#{row.role})" }.join(", "),
          proposed: candidate.contribution_rows.map { |row| "#{row['display_name']} (#{row['role']})" }.join(", "),
          default_apply: product.product_contributions.none?
        }
      ]
    end

    def review_submitted_values(selected)
      values = {}
      proposed = params[:proposed]
      Array(selected).each do |field|
        next if %w[contributions subjects cover_image].include?(field)

        if proposed&.key?(field)
          values[field] = proposed[field]
        elsif params.key?(field)
          values[field] = params[field]
        end
      end
      if selected.include?("contributions")
        values["contribution_rows"] = contribution_rows_from_review
      end
      if selected.include?("subjects")
        values["subject_rows"] = Bibliographic::SubjectMatcher.rows_for(@candidate&.subjects)
      end
      if selected.include?("product_form")
        values["product_form"] = proposed&.[]("product_form")
      end
      values
    end

    def format_review_money(cents)
      return if cents.nil?

      helpers.format_money_cents(cents)
    end

    def contribution_rows_from_review
      rows = params[:proposed_contribution_rows]
      return [] if rows.blank?

      hash = rows.respond_to?(:to_unsafe_h) ? rows.to_unsafe_h : rows.to_h
      hash.sort_by { |key, _| key.to_i }.map { |_, row|
        data = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
        data.stringify_keys.slice("display_name", "role")
      }
    end

    def product_form_options_for(product)
      forms = ProductForm.assignable.admin_ordered.to_a
      current = product&.product_form
      forms.unshift(current) if current && forms.exclude?(current)
      forms.map { |form| [ "#{form.name} (#{form.code})", form.id ] }
    end

    def product_form_name_for(code)
      return if code.blank?

      ProductForm.find_by(code: code.to_s.upcase)&.name || code
    end

    def render_form_with_money_error(template)
      @product ||= Product.new
      @product.assign_attributes(product_params.except(:list_price_cents, :lock_version)) if params[:product]
      @product.errors.add(:list_price, @money_error)
      load_form_options
      render template, status: :unprocessable_entity
    end

    def inventory_display_enabled?
      current_store.present? && effective_permissions.include?("inventory.view")
    end

    def load_product_on_hand_totals(product_ids)
      return {} if product_ids.empty?

      InventoryBalance.joins(:product_variant)
        .where(store_id: current_store.id, product_variants: { product_id: product_ids })
        .group("product_variants.product_id")
        .sum(:on_hand_quantity)
    end

    def load_variant_balances(variant_ids)
      return {} if variant_ids.empty?

      InventoryBalance.where(store_id: current_store.id, product_variant_id: variant_ids).index_by(&:product_variant_id)
    end

    def load_variant_on_order_quantities(variant_ids)
      return {} if variant_ids.empty? || current_store.blank?

      lines = PurchaseOrderLine
        .with_positive_open_quantity
        .joins(:purchase_order)
        .where(
          product_variant_id: variant_ids,
          purchase_orders: { store_id: current_store.id, status: "sent" }
        )
        .includes(:cancellations, purchase_receipt_lines: [ :purchase_receipt, :corrections ])

      lines.group_by(&:product_variant_id).transform_values { |group| group.sum(&:open_quantity) }
    end

    def load_product_purchasing_actions
      @stock_orderable_variants = []
      @requestable_variants = []
      return if current_store.blank?

      if effective_permissions.include?("orders.manage")
        @stock_orderable_variants = @product_variants.select { |v| stock_orderable_variant?(v) }
      end
      if effective_permissions.include?("customer_requests.manage")
        @requestable_variants = @product_variants.select { |v|
          customer_requestable_variant?(v, store: current_store)
        }
      end
      @single_stock_orderable = @stock_orderable_variants.one? ? @stock_orderable_variants.first : nil
      @single_requestable = @requestable_variants.one? ? @requestable_variants.first : nil
    end
  end
end
