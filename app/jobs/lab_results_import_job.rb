class LabResultsImportJob < ApplicationJob
  queue_as :default

  def perform(lab_upload_id)
    lab_upload = LabUpload.find(lab_upload_id)

    lab_upload.update!(
      started_at: Time.current,
      status: "pending",
      error_message: nil,
      parser_version: LabResults::ImportService::PARSER_VERSION
    )

    ::LabResults::ImportService.new(lab_upload).call

    lab_upload.update!(
      status: "completed",
      completed_at: Time.current,
      error_message: nil
    )
  rescue StandardError => e
    lab_upload&.update(status: "failed", error_message: e.message, completed_at: Time.current)
  end
end
