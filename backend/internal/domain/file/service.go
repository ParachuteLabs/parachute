package file

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Service provides file management for the Parachute folder structure
type Service struct {
	rootPath string
}

// NewService creates a new file service
func NewService(rootPath string) (*Service, error) {
	// Ensure root path exists
	if err := ensureDir(rootPath); err != nil {
		return nil, fmt.Errorf("failed to create root directory: %w", err)
	}

	// Ensure captures and spaces directories exist
	capturesPath := filepath.Join(rootPath, "captures")
	if err := ensureDir(capturesPath); err != nil {
		return nil, fmt.Errorf("failed to create captures directory: %w", err)
	}

	spacesPath := filepath.Join(rootPath, "spaces")
	if err := ensureDir(spacesPath); err != nil {
		return nil, fmt.Errorf("failed to create spaces directory: %w", err)
	}

	return &Service{
		rootPath: rootPath,
	}, nil
}

// SaveCapture saves an audio capture to the captures folder
func (s *Service) SaveCapture(audioData io.Reader, params UploadCaptureParams) (*CaptureMetadata, error) {
	// Generate filename from timestamp
	filename := formatTimestampForFilename(params.Timestamp) + ".wav"
	audioPath := filepath.Join(s.rootPath, "captures", filename)

	// Save audio file
	audioFile, err := os.Create(audioPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create audio file: %w", err)
	}
	defer audioFile.Close()

	written, err := io.Copy(audioFile, audioData)
	if err != nil {
		return nil, fmt.Errorf("failed to write audio file: %w", err)
	}

	// Create metadata
	now := time.Now()
	metadata := &CaptureMetadata{
		ID:            uuid.New().String(),
		Filename:      filename,
		Timestamp:     params.Timestamp,
		Duration:      params.Duration,
		Source:        params.Source,
		DeviceID:      params.DeviceID,
		Size:          written,
		HasTranscript: false,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	// Save metadata JSON
	if err := s.saveMetadataJSON(filename, metadata); err != nil {
		return nil, fmt.Errorf("failed to save metadata: %w", err)
	}

	return metadata, nil
}

// SaveTranscript saves a transcript for an existing capture
func (s *Service) SaveTranscript(filename string, data TranscriptData) error {
	// Verify audio file exists
	audioPath := filepath.Join(s.rootPath, "captures", filename)
	if _, err := os.Stat(audioPath); os.IsNotExist(err) {
		return fmt.Errorf("audio file not found: %s", filename)
	}

	// Load existing metadata
	metadata, err := s.loadMetadataJSON(filename)
	if err != nil {
		// If no metadata exists, create minimal metadata
		metadata = &CaptureMetadata{
			Filename:  filename,
			Timestamp: parseTimestampFromFilename(filename),
		}
	}

	// Update metadata
	metadata.HasTranscript = true
	metadata.TranscriptMode = data.TranscriptionMode
	metadata.ModelUsed = data.ModelUsed
	metadata.UpdatedAt = time.Now()

	// Generate markdown filename
	mdFilename := strings.TrimSuffix(filename, ".wav") + ".md"
	mdPath := filepath.Join(s.rootPath, "captures", mdFilename)

	// Generate markdown content
	markdown := s.generateTranscriptMarkdown(metadata, data.Transcript)

	// Save markdown file
	if err := os.WriteFile(mdPath, []byte(markdown), 0644); err != nil {
		return fmt.Errorf("failed to write transcript: %w", err)
	}

	// Update metadata JSON
	if err := s.saveMetadataJSON(filename, metadata); err != nil {
		return fmt.Errorf("failed to update metadata: %w", err)
	}

	return nil
}

// ListCaptures returns a list of all captures
func (s *Service) ListCaptures(limit, offset int) ([]CaptureInfo, int, error) {
	capturesDir := filepath.Join(s.rootPath, "captures")

	entries, err := os.ReadDir(capturesDir)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to read captures directory: %w", err)
	}

	// Collect all captures
	var captures []CaptureInfo
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".wav") {
			continue
		}

		// Load metadata
		metadata, err := s.loadMetadataJSON(entry.Name())
		if err != nil {
			// If no metadata, create minimal info from file
			info, err := entry.Info()
			if err != nil {
				continue
			}

			metadata = &CaptureMetadata{
				Filename:      entry.Name(),
				Timestamp:     parseTimestampFromFilename(entry.Name()),
				Size:          info.Size(),
				HasTranscript: s.transcriptExists(entry.Name()),
			}
		}

		captureInfo := CaptureInfo{
			Filename:      metadata.Filename,
			Timestamp:     metadata.Timestamp,
			Duration:      metadata.Duration,
			Source:        metadata.Source,
			Size:          metadata.Size,
			HasTranscript: metadata.HasTranscript,
			AudioURL:      "/api/captures/" + metadata.Filename,
		}

		if metadata.HasTranscript {
			mdFilename := strings.TrimSuffix(metadata.Filename, ".wav") + ".md"
			captureInfo.TranscriptURL = "/api/captures/" + mdFilename
		}

		captures = append(captures, captureInfo)
	}

	// Sort by timestamp descending (newest first)
	sort.Slice(captures, func(i, j int) bool {
		return captures[i].Timestamp.After(captures[j].Timestamp)
	})

	total := len(captures)

	// Apply pagination
	if offset >= len(captures) {
		return []CaptureInfo{}, total, nil
	}

	end := offset + limit
	if end > len(captures) {
		end = len(captures)
	}

	return captures[offset:end], total, nil
}

// GetCapture returns a reader for the audio file
func (s *Service) GetCapture(filename string) (io.ReadCloser, error) {
	audioPath := filepath.Join(s.rootPath, "captures", filename)

	file, err := os.Open(audioPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("capture not found: %s", filename)
		}
		return nil, fmt.Errorf("failed to open capture: %w", err)
	}

	return file, nil
}

// GetTranscript returns the transcript markdown content
func (s *Service) GetTranscript(filename string) (string, error) {
	mdFilename := strings.TrimSuffix(filename, ".wav") + ".md"
	mdPath := filepath.Join(s.rootPath, "captures", mdFilename)

	content, err := os.ReadFile(mdPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("transcript not found for: %s", filename)
		}
		return "", fmt.Errorf("failed to read transcript: %w", err)
	}

	return string(content), nil
}

// DeleteCapture deletes a capture and all associated files
func (s *Service) DeleteCapture(filename string) error {
	capturesDir := filepath.Join(s.rootPath, "captures")

	// Delete audio file
	audioPath := filepath.Join(capturesDir, filename)
	if err := os.Remove(audioPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete audio file: %w", err)
	}

	// Delete transcript if exists
	mdFilename := strings.TrimSuffix(filename, ".wav") + ".md"
	mdPath := filepath.Join(capturesDir, mdFilename)
	os.Remove(mdPath) // Ignore error if doesn't exist

	// Delete metadata JSON if exists
	jsonFilename := strings.TrimSuffix(filename, ".wav") + ".json"
	jsonPath := filepath.Join(capturesDir, jsonFilename)
	os.Remove(jsonPath) // Ignore error if doesn't exist

	return nil
}

// Helper functions

func (s *Service) saveMetadataJSON(filename string, metadata *CaptureMetadata) error {
	jsonFilename := strings.TrimSuffix(filename, ".wav") + ".json"
	jsonPath := filepath.Join(s.rootPath, "captures", jsonFilename)

	data, err := json.MarshalIndent(metadata, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(jsonPath, data, 0644)
}

func (s *Service) loadMetadataJSON(filename string) (*CaptureMetadata, error) {
	jsonFilename := strings.TrimSuffix(filename, ".wav") + ".json"
	jsonPath := filepath.Join(s.rootPath, "captures", jsonFilename)

	data, err := os.ReadFile(jsonPath)
	if err != nil {
		return nil, err
	}

	var metadata CaptureMetadata
	if err := json.Unmarshal(data, &metadata); err != nil {
		return nil, err
	}

	return &metadata, nil
}

func (s *Service) transcriptExists(filename string) bool {
	mdFilename := strings.TrimSuffix(filename, ".wav") + ".md"
	mdPath := filepath.Join(s.rootPath, "captures", mdFilename)
	_, err := os.Stat(mdPath)
	return err == nil
}

func (s *Service) generateTranscriptMarkdown(metadata *CaptureMetadata, transcript string) string {
	var sb strings.Builder

	// Frontmatter
	sb.WriteString("---\n")
	sb.WriteString(fmt.Sprintf("id: %s\n", metadata.ID))
	sb.WriteString(fmt.Sprintf("filename: %s\n", metadata.Filename))
	sb.WriteString(fmt.Sprintf("timestamp: %s\n", metadata.Timestamp.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf("duration: %.2f\n", metadata.Duration))
	sb.WriteString(fmt.Sprintf("source: %s\n", metadata.Source))

	if metadata.DeviceID != "" {
		sb.WriteString(fmt.Sprintf("deviceId: %s\n", metadata.DeviceID))
	}

	if metadata.TranscriptMode != "" {
		sb.WriteString(fmt.Sprintf("transcriptionMode: %s\n", metadata.TranscriptMode))
	}

	if metadata.ModelUsed != "" {
		sb.WriteString(fmt.Sprintf("modelUsed: %s\n", metadata.ModelUsed))
	}

	sb.WriteString("---\n\n")

	// Title
	title := fmt.Sprintf("Recording - %s", metadata.Timestamp.Format("January 2, 2006 3:04 PM"))
	sb.WriteString(fmt.Sprintf("# %s\n\n", title))

	// Metadata section
	sb.WriteString(fmt.Sprintf("**Duration:** %.1fs  \n", metadata.Duration))
	sb.WriteString(fmt.Sprintf("**Source:** %s  \n", metadata.Source))
	if metadata.TranscriptMode != "" {
		sb.WriteString(fmt.Sprintf("**Transcribed:** %s\n\n", metadata.TranscriptMode))
	}

	sb.WriteString("---\n\n")

	// Transcript content
	sb.WriteString(transcript)
	sb.WriteString("\n")

	return sb.String()
}

// formatTimestampForFilename converts a timestamp to filesystem-safe format
// Format: 2025-10-25_14-30-22
func formatTimestampForFilename(t time.Time) string {
	return fmt.Sprintf("%04d-%02d-%02d_%02d-%02d-%02d",
		t.Year(), t.Month(), t.Day(),
		t.Hour(), t.Minute(), t.Second())
}

// parseTimestampFromFilename attempts to parse timestamp from filename
func parseTimestampFromFilename(filename string) time.Time {
	// Extract: 2025-10-25_14-30-22 from filename
	parts := strings.Split(filename, "_")
	if len(parts) < 2 {
		return time.Now()
	}

	dateStr := parts[0]
	timeStr := strings.TrimSuffix(parts[1], ".wav")

	// Parse date
	dateParts := strings.Split(dateStr, "-")
	if len(dateParts) != 3 {
		return time.Now()
	}

	// Parse time
	timeParts := strings.Split(timeStr, "-")
	if len(timeParts) != 3 {
		return time.Now()
	}

	// Convert to time.Time
	layout := "2006-01-02_15-04-05"
	fullStr := fmt.Sprintf("%s_%s", dateStr, timeStr)
	t, err := time.Parse(layout, fullStr)
	if err != nil {
		return time.Now()
	}

	return t
}

// ensureDir ensures a directory exists, creating it if necessary
func ensureDir(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return os.MkdirAll(path, 0755)
		}
		return err
	}

	if !info.IsDir() {
		return fmt.Errorf("path exists but is not a directory: %s", path)
	}

	return nil
}
