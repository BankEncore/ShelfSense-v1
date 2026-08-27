#!/bin/bash

# One-shot local bootstrap. Does not overwrite an existing installation.
# Recreate first with: ./dev/rails-docker bin/rails db:reset
# Bootstrap the application
./dev/rails-docker env \
  ORGANIZATION_NAME="ShelfSense" \
  STORE_NUMBER=001 \
  STORE_CODE="001_mi_bloomfield_bloomfield_commons" \
  STORE_NAME="Bloomfield Books" \
  STORE_LEGAL_NAME="MI/Bloomfield Books" \
  STORE_TIMEZONE=America/New_York \
  STORE_COUNTRY_CODE=US \
  ADMIN_USERNAME=admin \
  ADMIN_DISPLAY_NAME="Admin User" \
  ADMIN_PASSWORD='ChangeMe123!' \
  bin/rails shelfsense:bootstrap