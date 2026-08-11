#!/bin/bash

# Bootstrap the application
./dev/rails-docker env \
  ORGANIZATION_NAME="Example Books" \
  STORE_NUMBER=001 \
  STORE_CODE=main \
  STORE_NAME="Main Store" \
  STORE_TIMEZONE=America/New_York \
  STORE_COUNTRY_CODE=US \
  ADMIN_USERNAME=admin \
  ADMIN_DISPLAY_NAME="Admin User" \
  ADMIN_PASSWORD='ChangeMe123!' \
  bin/rails shelfsense:bootstrap