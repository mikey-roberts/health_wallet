require "test_helper"
require "action_dispatch/testing/test_process"
require "digest"

class LabUploadsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionDispatch::TestProcess::FixtureFile

  test "should get index" do
    get lab_uploads_url
    assert_response :success
  end

  test "create enqueues processing and stores pending upload" do
    file = fixture_file_upload("lab_results_sample.txt", "text/plain")

    assert_enqueued_with(job: LabResultsImportJob) do
      post lab_uploads_url, params: { lab_upload: { file: file } }
    end

    upload = LabUpload.recent.first

    assert_not_nil upload
    assert_equal "pending", upload.status
    assert_equal "lab_results_sample.txt", upload.file
    assert_equal LabResults::ImportService::PARSER_VERSION, upload.parser_version
    assert_not_nil upload.file_checksum
    assert_redirected_to lab_uploads_path(upload_id: upload.id.to_s)
  end

  test "status returns upload details" do
    raw_content = "John Doe|1985-03-15|M|REF-1"

    upload = LabUpload.create!(
      file: "status.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "completed",
      completed_at: Time.current
    )

    get status_lab_upload_url(upload)

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal upload.id.to_s, json["id"]
    assert_equal "completed", json["status"]
    assert_equal "status.txt", json["file"]
  end
end
