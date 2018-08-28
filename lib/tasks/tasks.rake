require 'fhir_client'
require 'pry'
require './lib/sequence_base'
require File.expand_path '../../../app.rb', __FILE__
require './models/testing_instance'
require 'dm-core'
require 'csv'

['lib', 'models'].each do |dir|
  Dir.glob(File.join(File.expand_path('../..', File.dirname(File.absolute_path(__FILE__))),dir, '**','*.rb')).each do |file|
    require file
  end
end

desc 'Generate List of All Tests'
task :tests_to_csv do

  flat_tests = SequenceBase.ordered_sequences.map do |klass|
    klass.tests.map do |test|
      test[:sequence] = klass.to_s
      test[:sequence_required] = !klass.optional?
      test
    end
  end.flatten

  csv_out = CSV.generate do |csv|
    csv << ['Version', VERSION, 'Generated', Time.now]
    csv << ['', '', '', '', '']
    csv << ['Sequence/Group', 'Test Name', 'Required?', 'Description/Requirement', 'Reference URI']
    flat_tests.each do |test|
      csv <<  [ test[:sequence], test[:name], test[:sequence_required] && test[:required], test[:description], test[:url] ]
    end
  end

  puts csv_out

end

desc 'Execute sequence against a FHIR server'
task :execute_sequence, [:sequences, :server] do |task, args|

  @sequences = []
  input_sequences = args[:sequences].split(" ")
  input_sequences.each do |seq_arg|
    SequenceBase.ordered_sequences.map do |seq|
      if seq.sequence_name == seq_arg
        @selected_sequence = seq
        if @selected_sequence == nil
          puts "Sequence #{seq_arg} not found. Valid sequences are:
                  Conformance,
                  DynamicRegistration,
                  PatientStandaloneLaunch,
                  ProviderEHRLaunch,
                  OpenIDConnect,
                  TokenIntrospection,
                  TokenRefresh,
                  ArgonautDataQuery,
                  ArgonautProfiles,
                  AdditionalResources"
          exit
        else
          @sequences << @sequence
        end
      end
    end
  end

  @sequences.each do |seq_to_run|
    instance = TestingInstance.new(url: args[:server])
    instance.save!
    client = FHIR::Client.new(args[:server])
    client.use_dstu2
    client.default_json
    sequence_instance = seq_to_run.new(instance, client, true)
    sequence_result = sequence_instance.start
    
    puts "Sequence: " + seq_to_run.sequence_name
    sequence_result.test_results.each do |result|
      puts "\t Test Name: " + result.name + "\n" +
          "\t Test Result: " + result.result + "\n" +
          "\t Test Result Message: " + result.message + "\n" +
          "\t Test Description: " + result.description + "\n\n"
    end
  end
    
  
end

