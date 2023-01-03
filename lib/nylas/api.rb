# frozen_string_literal: true

module Nylas
  # Methods to retrieve data from the Nylas API as Ruby objects
  class API
    attr_accessor :client

    extend Forwardable
    def_delegators :client, :execute, :get, :post, :put, :delete, :client_id, :api_server

    include Logging

    # @param client [HttpClient] Http Client to use for retrieving data
    # @param client_id [String] Your application's client ID from the Nylas Dashboard
    # @param client_secret [String] Your application's client secret from the Nylas Dashboard
    # @param access_token [String] (Optional) Your users access token.
    # @param api_server [String] (Optional) Which Nylas API Server to connect to. Only change this if
    #                            you're using a self-hosted Nylas instance.
    # @return [Nylas::API]
    def initialize(client: nil, client_id: nil, client_secret: nil, access_token: nil,
                   api_server: "https://api.nylas.com")
      self.client = client || HttpClient.new(client_id: client_id, client_secret: client_secret,
                                             access_token: access_token, api_server: api_server)
    end

    # @return [String] A Nylas access token for that particular user.
    def authenticate(name:, email_address:, provider:, settings:, reauth_account_id: nil, scopes: nil)
      NativeAuthentication.new(api: self).authenticate(
        name: name,
        email_address: email_address,
        provider: provider,
        settings: settings,
        reauth_account_id: reauth_account_id,
        scopes: scopes
      )
    end

    def authentication_url(redirect_uri:, scopes:, response_type: "code", login_hint: nil, state: nil,
                           provider: nil, redirect_on_error: nil, disable_provider_selection: nil)
      params = { client_id: client_id, redirect_uri: redirect_uri, response_type: response_type,
                 login_hint: login_hint }

      params[:state] = state if state
      params[:scopes] = scopes.join(",") if scopes
      params[:provider] = provider if provider
      params[:redirect_on_error] = redirect_on_error if redirect_on_error
      params[:disable_provider_selection] = disable_provider_selection if disable_provider_selection

      "#{api_server}/oauth/authorize?#{URI.encode_www_form(params)}"
    end

    # Exchanges an authorization code for an access token
    # @param code [String] The authorization code to exchange
    # @param return_full_response [Boolean] If true, returns the full response body instead of just the token
    # @return [String | Hash] Returns just the access token as a string, or the full response as a hash
    def exchange_code_for_token(code, return_full_response: false)
      data = {
        "client_id" => client_id,
        "client_secret" => client.client_secret,
        "grant_type" => "authorization_code",
        "code" => code
      }

      response = execute(method: :post, path: "/oauth/token", payload: data)
      return_full_response ? response : response[:access_token]
    end

    # @return [Collection<Contact>] A queryable collection of Contacts
    def contacts
      @contacts ||= Collection.new(model: Contact, api: self)
    end

    # @return [Collection<ContactGroup>] A queryable collection of Contact Groups
    def contact_groups
      @contact_groups ||= Collection.new(model: ContactGroup, api: self)
    end

    # @return [CurrentAccount] The account details for whomevers access token is set
    def current_account
      prevent_calling_if_missing_access_token(:current_account)
      CurrentAccount.from_hash(execute(method: :get, path: "/account"), api: self)
    end

    # @return [Collection<Account>] A queryable collection of {Account}s
    def accounts
      @accounts ||= Collection.new(model: Account, api: as(client.client_secret))
    end

    # @return [CalendarCollection<Calendar>] A queryable collection of {Calendar}s
    def calendars
      @calendars ||= CalendarCollection.new(model: Calendar, api: self)
    end

    # @return [DeltasCollection<Delta>] A queryable collection of Deltas, which are themselves a collection.
    def deltas
      @deltas ||= DeltasCollection.new(api: self)
    end

    # @return[Collection<Draft>] A queryable collection of {Draft} objects
    def drafts
      @drafts ||= Collection.new(model: Draft, api: self)
    end

    # @return [EventCollection<Event>] A queryable collection of {Event}s
    def events
      @events ||= EventCollection.new(model: Event, api: self)
    end

    # @return [Collection<Folder>] A queryable collection of {Folder}s
    def folders
      @folders ||= Collection.new(model: Folder, api: self)
    end

    # @return [Collection<File>] A queryable collection of {File}s
    def files
      @files ||= Collection.new(model: File, api: self)
    end

    # @return [Collection<Label>] A queryable collection of {Label} objects
    def labels
      @labels ||= Collection.new(model: Label, api: self)
    end

    # @return[Collection<Message>] A queryable collection of {Message} objects
    def messages
      @messages ||= Collection.new(model: Message, api: self)
    end

    # @return[Collection<RoomResource>] A queryable collection of {RoomResource} objects
    def room_resources
      @room_resources ||= Collection.new(model: RoomResource, api: self)
    end

    # @return[Collection<JobStatus>] A queryable collection of {JobStatus} objects
    def job_statuses
      @job_statuses ||= JobStatusCollection.new(model: JobStatus, api: self)
    end

    # @return[OutboxCollection] A collection of Outbox operations
    def outbox
      @outbox ||= Outbox.new(api: self)
    end

    # @return[SchedulerCollection<Scheduler>] A queryable collection of {Scheduler} objects
    def scheduler
      # Make a deep copy of the API as the scheduler API uses a different base URL
      scheduler_api = Marshal.load(Marshal.dump(self))
      scheduler_api.client.api_server = "https://api.schedule.nylas.com"
      @scheduler ||= SchedulerCollection.new(model: Scheduler, api: scheduler_api)
    end

    # @return[Neural] A collection of Neural operations
    def neural
      @neural ||= Neural.new(api: self)
    end

    # @return [Collection<Component>] A queryable collection of {Component}s
    def components
      @components ||= ComponentCollection.new(model: Component, api: as(client.client_secret))
    end

    # Revokes access to the Nylas API for the given access token
    # @return [Boolean]
    def revoke(access_token)
      response = client.as(access_token).post(path: "/oauth/revoke")
      response.code == 200 && response.empty?
    end

    # Returns the application details
    # @return [ApplicationDetail] The application details
    def application_details
      response = client.as(client.client_secret).execute(
        method: :get,
        path: "/a/#{client_id}",
        auth_method: HttpClient::AuthMethod::BASIC
      )
      ApplicationDetail.new(**response)
    end

    # Updates the application details
    # @param application_details [ApplicationDetail] The updated application details
    # @return [ApplicationDetails] The updated application details, returned from the server
    def update_application_details(application_details)
      response = client.as(client.client_secret).execute(
        method: :put,
        path: "/a/#{client_id}",
        payload: JSON.dump(application_details.to_h),
        auth_method: HttpClient::AuthMethod::BASIC
      )
      ApplicationDetail.new(**response)
    end

    # Returns list of IP addresses
    # @return [Hash]
    # hash has keys of :updated_at (unix timestamp) and :ip_addresses (array of strings)
    def ip_addresses
      path = "/a/#{client_id}/ip_addresses"
      client.as(client.client_secret).get(path: path, auth_method: HttpClient::AuthMethod::BASIC)
    end

    # @param message [Hash, String, #send!]
    # @return [Message] The resulting message
    def send!(message)
      return message.send! if message.respond_to?(:send!)
      return NewMessage.new(**message.merge(api: self)).send! if message.respond_to?(:key?)
      return RawMessage.new(message, api: self).send! if message.is_a? String
    end

    # Allows you to get an API that acts as a different user but otherwise has the same settings
    # @param access_token [String] Oauth Access token or app secret used to authenticate with the API
    # @return [API]
    def as(access_token)
      API.new(client: client.as(access_token))
    end

    # @return [Collection<Thread>] A queryable collection of Threads
    def threads
      @threads ||= Collection.new(model: Thread, api: self)
    end

    # @return [Collection<Webhook>] A queryable collection of {Webhook}s
    def webhooks
      @webhooks ||= Collection.new(model: Webhook, api: as(client.client_secret))
    end

    # TODO: Move this into calendar collection
    def free_busy(emails:, start_time:, end_time:)
      FreeBusyCollection.new(
        api: self,
        emails: emails,
        start_time: start_time.to_i,
        end_time: end_time.to_i
      )
    end

    private

    def prevent_calling_if_missing_access_token(method_name)
      return if client.access_token && !client.access_token.empty?

      raise NoAuthToken, method_name
    end
  end
end
