require 'test_helper'

class TestBatch < Test::Unit::TestCase
  
  def setup
    options = {
      :username => 'myusername', 
      :password => 'mypassword',
      :token => "somelongtoken"
    }
    
    @client = SalesforceBulk::Client.new(options)
    @batch = SalesforceBulk::Batch.new
    @headers = {"Content-Type" => "text/csv; charset=UTF-8", 'X-Sfdc-Session' => '123456789'}
  end
  
  test "state?" do
    @batch.state = "Completed"
    assert @batch.state?('Completed')
    
    @batch.state = "COMPLETED"
    assert @batch.state?('completed')
    
    @batch.state = "Failed"
    assert !@batch.state?('Queued')
  end
  
  test "state is marked queued" do
    @batch.state = "Queued"
    assert @batch.queued?
    
    @batch.state = nil
    assert !@batch.queued?
  end
  
  test "state is marked in progress" do
    @batch.state = "InProgress"
    assert @batch.in_progress?
    
    @batch.state = nil
    assert !@batch.in_progress?
  end
  
  test "state is marked completed" do
    @batch.state = "Completed"
    assert @batch.completed?
    
    @batch.state = nil
    assert !@batch.completed?
  end
  
  test "state is marked failed" do
    @batch.state = "Failed"
    assert @batch.failed?
    
    @batch.state = nil
    assert !@batch.failed?
  end
  
  test "should add a batch to a job and return a successful response" do
    request = fixture("batch_create_request.csv")
    response = fixture("batch_create_response.xml")
    job_id = "750E00000004NRfIAM"
    batch_id = "751E00000004ZmUIAU"
    data = [
      {:Id__c => '12345', :Title__c => "This is a test video", :IsPreview__c => nil},
      {:Id__c => '23456', :Title__c => "A second test!", :IsPreview__c => true}
    ]
    
    bypass_authentication(@client)
    stub_request(:post, "#{api_url(@client)}job/#{job_id}/batch")
      .with(:body => request, :headers => @headers)
      .to_return(:body => response, :status => 200)
    
    batch = @client.add_batch(job_id, data)
    
    assert_requested :post, "#{api_url(@client)}job/#{job_id}/batch", :body => request, :headers => @headers, :times => 1
    
    assert_equal batch.id, batch_id
    assert_equal batch.job_id, job_id
    assert_equal batch.state, 'Queued'
  end
  
  test "should retrieve info for all batches in a job in a single request" do
    response = fixture("batch_info_list_response.xml")
    job_id = "750E00000004N97IAE"
    
    bypass_authentication(@client)
    stub_request(:get, "#{api_url(@client)}job/#{job_id}/batch").to_return(:body => response, :status => 200)
    
    batches = @client.batch_info_list(job_id)
    
    assert_requested :get, "#{api_url(@client)}job/#{job_id}/batch", :times => 1
    
    assert_kind_of Array, batches
    assert_kind_of SalesforceBulk::Batch, batches.first
    
    assert_equal batches.length, 2
    assert_equal batches.first.job_id, job_id
    assert_equal batches.first.id, "751E00000004ZRbIAM"
    assert_equal batches[1].job_id, job_id
    assert_equal batches[1].id, "751E00000004ZQsIAM"
  end
  
  test "should retrieve batch info" do
    response = fixture("batch_info_response.xml")
    job_id = "750E00000004N97IAE"
    batch_id = "751E00000004ZRbIAM"
    
    bypass_authentication(@client)
    stub_request(:get, "#{api_url(@client)}job/#{job_id}/batch/#{batch_id}")
      .with(:headers => @headers)
      .to_return(:body => response, :status => 200)
    
    batch = @client.batch_info(job_id, batch_id)
    
    assert_requested :get, "#{api_url(@client)}job/#{job_id}/batch/#{batch_id}", :headers => @headers, :times => 1
    
    assert_equal batch.job_id, job_id
    assert_equal batch.state, 'Completed'
  end
  
  test "should return batch result for a non-querying job" do
    response = fixture("batch_result_list_response.csv")
    job_id = "750E00000004NRa"
    batch_id = "751E00000004ZmK"
    
    # Batches that are created using CSV will always return 
    # results in CSV format despite requesting with XML content type.
    # Thus the content type header is ignored.
    
    bypass_authentication(@client)
    stub_request(:get, "#{api_url(@client)}job/#{job_id}/batch/#{batch_id}/result").to_return(:body => response, :status => 200)
    
    results = @client.batch_result_list(job_id, batch_id)
    
    assert_requested :get, "#{api_url(@client)}job/#{job_id}/batch/#{batch_id}/result", :times => 1
    
    assert_kind_of SalesforceBulk::BatchResultCollection, results
    assert_kind_of Array, results
    
    assert_equal results.job_id, job_id
    assert_equal results.batch_id, batch_id
    
    assert_equal results.first.success, true
    assert_equal results.first.created, false
    assert_equal results.first.error?, false
    assert_equal results.first.error, ''
  end
  
end