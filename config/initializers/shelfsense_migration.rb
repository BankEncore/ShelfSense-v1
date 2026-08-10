# frozen_string_literal: true

require "shelfsense/migration"

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include(Shelfsense::Migration)
end
