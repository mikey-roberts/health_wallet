class LabUpload
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file, type: String
  field :raw_content, type: String
  field :file_checksum, type: String
  field :parser_version, type: String
  field :status, type: String, default: "pending"
  field :error_message, type: String
  field :started_at, type: Time
  field :completed_at, type: Time

  validates :file, presence: true
  validates :raw_content, presence: true
  validates :file_checksum, presence: true
  validates :parser_version, presence: true
  validates :status, inclusion: { in: %w[pending completed failed] }

  scope :recent, -> { desc(:created_at) }
end
