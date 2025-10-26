package file

import (
	"time"
)

// CaptureMetadata represents metadata for a voice recording
type CaptureMetadata struct {
	ID             string    `json:"id"`
	Filename       string    `json:"filename"`
	Timestamp      time.Time `json:"timestamp"`
	Duration       float64   `json:"duration"` // seconds
	Source         string    `json:"source"`   // phone, omi, desktop
	DeviceID       string    `json:"deviceId,omitempty"`
	Size           int64     `json:"size"`
	HasTranscript  bool      `json:"hasTranscript"`
	TranscriptMode string    `json:"transcriptMode,omitempty"` // api, local
	ModelUsed      string    `json:"modelUsed,omitempty"`
	Tags           []string  `json:"tags,omitempty"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

// CaptureInfo represents a summary of a capture for listing
type CaptureInfo struct {
	Filename      string    `json:"filename"`
	Timestamp     time.Time `json:"timestamp"`
	Duration      float64   `json:"duration"`
	Source        string    `json:"source"`
	Size          int64     `json:"size"`
	HasTranscript bool      `json:"hasTranscript"`
	AudioURL      string    `json:"audioUrl"`
	TranscriptURL string    `json:"transcriptUrl,omitempty"`
}

// TranscriptData represents transcript content and metadata
type TranscriptData struct {
	Transcript        string `json:"transcript"`
	TranscriptionMode string `json:"transcriptionMode"` // api, local
	ModelUsed         string `json:"modelUsed,omitempty"`
}

// UploadCaptureParams represents parameters for uploading a capture
type UploadCaptureParams struct {
	Timestamp time.Time
	Duration  float64
	Source    string
	DeviceID  string
}
