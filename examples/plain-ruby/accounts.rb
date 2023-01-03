require_relative '../helpers'

# An executable specification that demonstrates how to use the Nylas Ruby SDK to interact with the API. It
# follows the rough structure of the [Nylas API Reference](https://docs.nylas.com/reference).
api = Nylas::API.new(client_id: ENV['NYLAS_APP_ID'], client_secret: ENV['NYLAS_APP_SECRET'],
                     access_token: ENV['NYLAS_ACCESS_TOKEN'])

# Retrieving the account information for given access token
demonstrate { api.current_account.to_h }

# Retrieving the accounts you may manage
demonstrate { api.accounts.limit(5).map(&:to_h) }

# Deactivating an account
account = api.accounts.first
demonstrate { account.downgrade }
demonstrate { account.to_h }

# Activating an account
demonstrate { account.upgrade }
demonstrate { account.to_h }

# Get token info for access token
demonstrate { api.accounts.first.token_info(ENV['NYLAS_ACCESS_TOKEN']).to_h }

# Getting application details
demonstrate { api.application_details }
