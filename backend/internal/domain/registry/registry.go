package registry

import (
	"time"
)

// Space represents a registered space that can be located anywhere on the filesystem
type Space struct {
	ID           string    `json:"id"`
	Path         string    `json:"path"` // Absolute path to space folder
	Name         string    `json:"name"` // Display name (defaults to folder name)
	AddedAt      time.Time `json:"added_at"`
	LastAccessed time.Time `json:"last_accessed,omitempty"`
	Config       string    `json:"config,omitempty"` // JSON: {color, icon, folder_names}
}

// Capture represents a note/recording in the system
type Capture struct {
	ID            string    `json:"id"`
	BaseName      string    `json:"base_name"` // e.g., "2025-10-29_soil-health-discussion"
	Title         string    `json:"title"`     // Display title: "Soil Health Discussion"
	CreatedAt     time.Time `json:"created_at"`
	HasAudio      bool      `json:"has_audio"`
	HasTranscript bool      `json:"has_transcript"`
	Metadata      string    `json:"metadata,omitempty"` // JSON from .json file
}

// Setting represents a key-value configuration setting
type Setting struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// AddSpaceParams represents parameters for adding a space
type AddSpaceParams struct {
	Path   string `json:"path"`           // Absolute path to space folder
	Name   string `json:"name,omitempty"` // Optional display name
	Config string `json:"config,omitempty"`
}

// CreateSpaceParams represents parameters for creating a new space
type CreateSpaceParams struct {
	Name   string `json:"name"`
	Path   string `json:"path"` // Where to create the space
	Config string `json:"config,omitempty"`
}

// AddCaptureParams represents parameters for registering a capture
type AddCaptureParams struct {
	BaseName      string `json:"base_name"`
	Title         string `json:"title"`
	HasAudio      bool   `json:"has_audio"`
	HasTranscript bool   `json:"has_transcript"`
	Metadata      string `json:"metadata,omitempty"`
}
