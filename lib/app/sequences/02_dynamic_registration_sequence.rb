module Inferno
  module Sequence
    class DynamicRegistrationSequence < SequenceBase

      title 'Dynamic Registration'

      description 'Verify that the server supports the OAuth 2.0 Dynamic Client Registration Protocol.'

      details %(
        # Background

        An app that is requesting patient data on behalf of the user must first be registered with the EHR's authorization service.  This
        can either be done manually, typically through a web interface provided to the app developer, or
        programatically using the [OAuth 2.0 Dynamic Client Registration Protocol](https://tools.ietf.org/html/rfc7591).
        This functionality is *OPTIONAL* but is recommended by the SMART App Launch framework.

        Dynamic registration is typically used in one of two ways:

        * As a method to reduce the burden of registering an app manually for each EHR's authorization service.
        * As a method to register each app *instance* to improve security of secrets in confidential apps.

        # Test Methodology

        This sequence tests Dynamic Registration by registering a single instance of this Inferno application.  It allows the
        user to dynamically register a public or confidential client and specify which scopes to allow for this client.  If successful, the state of the
        application is updated to store the client id, scopes, and if necessary, the the client secret.  This information is used
        in later tests for the app launch sequences.

        The SMART App Launch guide requires the implementation of both public and confidential client functionality within the
        authorization service.  Since this sequence does not automatically register both types of clients, users should run this sequence using both
        methods to ensure that the application is capable of registering both modes.  Similarly, the default scopes represent the most permissive allowed
        by the Smart App Launch guide.  Users should alter this scope depending on the nature of the tests.

        Althought requiring users to manually perform each of these combinations may be combersome for mature implementations, it allows developers to incrementally
        test different combinations quickly without burdening their system with potentially thousands of tests.  The command line features of Inferno
        allow users to define scripts that perform each of these permutations, and the web interface may provide this functionality in the future.


      )

      test_id_prefix 'DR'

      optional

      requires :oauth_register_endpoint, :client_name, :initiate_login_uri, :redirect_uris, :scopes, :confidential_client,:initiate_login_uri, :redirect_uris
      defines :client_id, :client_secret

      test 'Client registration endpoint secured by transport layer security' do

        metadata {
          id '01'
          link 'https://www.hl7.org/fhir/security.html'
          optional
          desc %(
            The client registration endpoint MUST be protected by a transport layer security.
          )
        }

        skip 'TLS tests have been disabled by configuration.' if @disable_tls_tests
        assert_tls_1_2 @instance.oauth_register_endpoint
        warning {
          assert_deny_previous_tls @instance.oauth_register_endpoint
        }
      end

      test 'Client registration endpoint accepts POST messages' do

        metadata {
          id '02'
          link 'https://tools.ietf.org/html/rfc7591'
          desc %(
            The client registration endpoint MUST accept HTTP POST messages with request parameters encoded in the entity body using the "application/json" format.
          )
        }
        # params['redirect_uris'] = [params['redirect_uris']]
        # params['grant_types'] = params['grant_types'].split(',')
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }

        params = {
            'client_name' => @instance.client_name,
            'initiate_login_uri' => "#{@instance.base_url}#{BASE_PATH}/#{@instance.id}/#{@instance.client_endpoint_key}/launch",
            'redirect_uris' => ["#{@instance.base_url}#{BASE_PATH}/#{@instance.id}/#{@instance.client_endpoint_key}/redirect"],
            'grant_types' => ['authorization_code'],
            'scope' => @instance.scopes,
        }

        params['token_endpoint_auth_method'] = if @instance.confidential_client
                                                 'client_secret_basic'
                                               else
                                                 'none'
                                               end

        @registration_response = LoggedRestClient.post(@instance.oauth_register_endpoint, params.to_json, headers)
        @registration_response_body = JSON.parse(@registration_response.body)

      end

      test 'Registration endpoint does not respond with an error' do

        metadata {
          id '03'
          link 'https://tools.ietf.org/html/rfc7591'
          desc %(
            When an OAuth 2.0 error condition occurs, such as the client presenting an invalid initial access token, the authorization server returns an error response appropriate to the OAuth 2.0 token type.
          )
        }

        assert !@registration_response_body.has_key?('error') && !@registration_response_body.has_key?('error_description'),
               "Error returned.  Error: #{@registration_response_body['error']}, Description: #{@registration_response_body['error_description']}"

      end

      test 'Registration endpoint responds with HTTP 201 and body contains JSON with required fields' do

        metadata {
          id '04'
          link 'https://tools.ietf.org/html/rfc7591'
          desc %(
            The server responds with an HTTP 201 Created status code and a body of type "application/json" with content as described in Section 3.2.1.
          )
        }

        assert @registration_response.code == 201, "Expected HTTP 201 response from registration endpoint but received #{@registration_response.code}"
        assert @registration_response_body.has_key?('client_id') && @registration_response_body.has_key?('scope'), 'Registration response did not include client_id and scope fields in JSON body'


        # TODO: check all values, and not just client and scope

        update_params ={
            client_id: @registration_response_body['client_id'],
            dynamically_registered: true,
            scopes: @registration_response_body['scope']
        }

        if @instance.confidential_client
          update_params.merge!(client_secret: @registration_response_body['client_secret'])
        end

        @instance.update(update_params)
      end
    end

  end
end
