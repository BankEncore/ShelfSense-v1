# frozen_string_literal: true

module OpsHelper
  OPS_SHORTCUT_PROFILES = {
    location: {
      workspace: "location",
      buttons: [],
      help: [
        [ "↑ ↓", "Select a request row" ],
        [ "Enter", "Open the selected request" ],
        [ "Esc", "Close the action panel without saving" ]
      ]
    },
    draft_po: {
      workspace: "draft_po",
      buttons: [
        { label: "Focus lookup", keys: "/", action: "ops-shortcuts#focusLookup" },
        { label: "Save", keys: "Ctrl/⌘ S", action: "ops-shortcuts#save" },
        { label: "Primary action", keys: "Ctrl/⌘ Enter", action: "ops-shortcuts#primary" },
        { label: "Cancel current selection/edit", keys: "Esc", action: "escape-cancel#cancel" }
      ],
      help: [
        [ "/", "Focus lookup or scan input" ],
        [ "↑ ↓", "Select a row" ],
        [ "Enter", "Activate the selected row or submit the current scan" ],
        [ "Esc", "Cancel the current selection/edit without saving" ],
        [ "Ctrl/⌘ S", "Save the current edit" ],
        [ "Ctrl/⌘ Enter", "Run the labeled primary action" ]
      ]
    },
    receiving: {
      workspace: "receiving",
      buttons: [
        { label: "Focus lookup", keys: "/", action: "ops-shortcuts#focusLookup" },
        { label: "Save", keys: "Ctrl/⌘ S", action: "ops-shortcuts#save" },
        { label: "Primary action", keys: "Ctrl/⌘ Enter", action: "ops-shortcuts#primary" },
        { label: "Cancel current selection/edit", keys: "Esc", action: "escape-cancel#cancel" }
      ],
      help: [
        [ "/", "Focus lookup or scan input" ],
        [ "↑ ↓", "Select a row" ],
        [ "Enter", "Activate the selected row or submit the current scan" ],
        [ "Esc", "Close help or cancel the current selection/edit without saving" ],
        [ "Ctrl/⌘ S", "Save the current edit" ],
        [ "Ctrl/⌘ Enter", "Run the labeled primary action" ]
      ]
    }
  }.freeze

  def ops_shortcuts_profile
    OPS_SHORTCUT_PROFILES.fetch(ops_workspace_key, OPS_SHORTCUT_PROFILES[:draft_po])
  end

  def ops_workspace_key
    case controller.controller_path
    when "ops/locations" then :location
    when "ops/draft_pos" then :draft_po
    when "ops/receiving" then :receiving
    else :draft_po
    end
  end
end
