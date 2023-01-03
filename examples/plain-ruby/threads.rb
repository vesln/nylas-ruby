require_relative '../helpers'

# An executable specification that demonstrates how to use the Nylas Ruby SDK to interact with the API. It
# follows the rough structure of the [Nylas API Reference](https://docs.nylas.com/reference).
api = Nylas::API.new(client_id: ENV['NYLAS_APP_ID'], client_secret: ENV['NYLAS_APP_SECRET'],
                     access_token: ENV['NYLAS_ACCESS_TOKEN'])


# How many threads are there?
demonstrate { api.threads.count }

thread = api.threads.first
# Threads have quite a bit of information
demonstrate { thread.to_h }

# Threads may be expanded
# demonstrate { api.threads.expanded.first }

# Threads may have their unread/starred statuses updated
demonstrate { thread.update(starred: true, unread: true) }
reloaded_thread = api.threads.first
demonstrate { { starred: reloaded_thread.starred, unread: reloaded_thread.unread } }

# Threads cannot be created
demonstrate do
  begin
    api.threads.create
  rescue Nylas::ModelNotCreatableError => e
    "#{e.class}: #{e.message}"
  end
end



# Threads may not be destroyed
demonstrate do
  begin
    thread.destroy
  rescue Nylas::ModelNotDestroyableError => e
    "#{e.class}: #{e.message}"
  end
end


# Threads may be searched.
# See https://docs.nylas.com/reference#search-threads and https://docs.nylas.com/reference#search
demonstrate { api.threads.search("That really important email").map(&:to_h) }

