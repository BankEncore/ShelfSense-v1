# frozen_string_literal: true

module Admin
  class NavigationViewModel
    VisibleGroup = Data.define(:key, :label, :current, :destinations)
    VisibleDestination = Data.define(:key, :label, :path, :current)

    def initialize(
      user:,
      permissions:,
      current_store:,
      accessible_stores:,
      controller_path:,
      routes: Rails.application.routes.url_helpers
    )
      @user = user
      @permissions = permissions
      @current_store = current_store
      @accessible_stores = accessible_stores
      @controller_path = controller_path.to_s
      @routes = routes
    end

    def groups
      @groups ||= build_groups
    end

    def current_destination
      groups.flat_map(&:destinations).find(&:current)
    end

    def current_group
      groups.find(&:current)
    end

    def show_switch_store?
      @accessible_stores.many?
    end

    def any_destination_visible?
      groups.any?
    end

    private

    def build_groups
      current_key = nil
      visible = NavigationCatalog.groups.filter_map do |group|
        destinations = group.destinations.filter_map { |destination| visible_destination(destination) }
        next if destinations.empty?

        VisibleGroup.new(
          key: group.key,
          label: group.label,
          current: false,
          destinations: destinations
        )
      end

      current_destination = find_current_destination(visible)
      if current_destination
        current_key = current_destination.key
        visible.map do |group|
          destinations = group.destinations.map do |destination|
            VisibleDestination.new(
              key: destination.key,
              label: destination.label,
              path: destination.path,
              current: destination.key == current_key
            )
          end
          VisibleGroup.new(
            key: group.key,
            label: group.label,
            current: destinations.any?(&:current),
            destinations: destinations
          )
        end
      else
        visible
      end
    end

    def find_current_destination(visible_groups)
      NavigationCatalog.destinations.each do |catalog_destination|
        next unless catalog_destination.controllers.include?(@controller_path)

        visible_groups.each do |group|
          match = group.destinations.find { |d| d.key == catalog_destination.key }
          return match if match
        end
      end
      nil
    end

    def visible_destination(destination)
      return unless destination_allowed?(destination)
      return if destination.requires_store && @current_store.blank?

      VisibleDestination.new(
        key: destination.key,
        label: destination.label,
        path: path_for(destination),
        current: false
      )
    end

    def destination_allowed?(destination)
      if destination.hub
        return Purchasing::HubAccess.nav_visible?(user: @user, accessible_stores: @accessible_stores)
      end

      case destination.permission
      when Array
        destination.permission.any? { |key| @permissions.include?(key) }
      when String
        @permissions.include?(destination.permission)
      else
        false
      end
    end

    def path_for(destination)
      @routes.public_send(destination.path_method, *destination.path_args)
    end
  end
end
