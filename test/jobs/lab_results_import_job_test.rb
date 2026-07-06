require "test_helper"
require "digest"

class LabResultsImportJobTest < ActiveJob::TestCase
  test "imports assessments and observations from uploaded file" do
    raw_content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-001
      8480-6|120|mmHg
      8462-4|80|mmHg
    HL7

    upload = LabUpload.create!(
      file: "valid_hl7.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    )

    LabResultsImportJob.perform_now(upload.id.to_s)

    upload.reload
    patient = Patient.where(name: "John Doe").first
    assessment = patient.assessments.where(reference: "REF-2024-001").first
    systolic = assessment.observations.where(code: "8480-6").first

    assert_equal "completed", upload.status
    assert_not_nil upload.started_at
    assert_not_nil upload.completed_at
    assert_not_nil patient
    assert_not_nil assessment
    assert_equal 120.0, systolic.value
    assert_equal "mmHg", systolic.units
  end

  test "marks upload as failed for invalid content" do
    raw_content = "bad_line_without_delimiters"

    upload = LabUpload.create!(
      file: "invalid_hl7.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    )

    LabResultsImportJob.perform_now(upload.id.to_s)

    upload.reload

    assert_equal "failed", upload.status
    assert_match "Invalid line format", upload.error_message
    assert_not_nil upload.started_at
    assert_not_nil upload.completed_at
  end

  test "updates existing assessment and observation by reference and code" do
    patient = Patient.create!(name: "Jane Smith", dob: Date.iso8601("1990-07-22"), sex_at_birth: "Female")
    assessment = patient.assessments.create!(reference: "REF-2024-002", date: "2024-07-01")
    assessment.observations.create!(name: "Blood Pressure (Systolic)", code: "8480-6", value: 110.0, units: "mmHg")

    raw_content = <<~HL7
      Jane Smith|1990-07-22|F|REF-2024-002
      8480-6|118|mmHg
    HL7

    upload = LabUpload.create!(
      file: "update_existing.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    )

    LabResultsImportJob.perform_now(upload.id.to_s)

    upload.reload
    assessment.reload
    updated_obs = assessment.observations.where(code: "8480-6").first

    assert_equal "completed", upload.status
    assert_equal 118.0, updated_obs.value
  end

  test "ignores unsupported observation codes and tracks ignored count" do
    raw_content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-010
      9999-9|123|u
      8480-6|120|mmHg
    HL7

    upload = LabUpload.create!(
      file: "unsupported_code.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    )

    LabResultsImportJob.perform_now(upload.id.to_s)

    upload.reload
    patient = Patient.where(name: "John Doe").first
    assessment = patient.assessments.where(reference: "REF-2024-010").first

    assert_equal "completed", upload.status
    assert_equal 1, assessment.observations.count
    assert_equal "8480-6", assessment.observations.first.code
  end

  test "supports multiple assessment headers in one file" do
    raw_content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-100
      8480-6|121|mmHg
      John Doe|1985-03-15|M|REF-2024-101
      8462-4|79|mmHg
    HL7

    upload = LabUpload.create!(
      file: "multiple_assessments.txt",
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    )

    LabResultsImportJob.perform_now(upload.id.to_s)

    upload.reload
    patient = Patient.where(name: "John Doe").first

    assert_equal "completed", upload.status
    assert_not_nil patient.assessments.where(reference: "REF-2024-100").first
    assert_not_nil patient.assessments.where(reference: "REF-2024-101").first
  end
end
