require "digest"

class LabUploadsController < ApplicationController
  def index
    @active_upload = LabUpload.where(id: params[:upload_id]).first if params[:upload_id].present?
    @uploads = LabUpload.recent.limit(10)
  end

  def create
    uploaded_file = params.dig(:lab_upload, :file)
    @lab_upload = LabUpload.new(build_upload_attributes(uploaded_file))

    if @lab_upload.save
      LabResultsImportJob.perform_later(@lab_upload.id.to_s)
      redirect_to lab_uploads_path(upload_id: @lab_upload.id.to_s), notice: "Upload queued and processing started."
    else
      @uploads = LabUpload.recent.limit(10)
      render :index, status: :unprocessable_entity
    end
  end

  def status
    lab_upload = LabUpload.find(params[:id])

    render json: {
      id: lab_upload.id.to_s,
      file: lab_upload.file,
      status: lab_upload.status,
      error_message: lab_upload.error_message,
      completed_at: lab_upload.completed_at,
      created_at: lab_upload.created_at
    }
  end

  private

  def build_upload_attributes(uploaded_file)
    return {} unless uploaded_file.present?

    raw_content = normalize_utf8(uploaded_file.read)

    {
      file: normalize_utf8(uploaded_file.original_filename),
      raw_content: raw_content,
      file_checksum: Digest::SHA256.hexdigest(raw_content),
      parser_version: LabResults::ImportService::PARSER_VERSION,
      status: "pending"
    }
  end

  def normalize_utf8(value)
    value.to_s.force_encoding(Encoding::UTF_8).scrub
  end
end
