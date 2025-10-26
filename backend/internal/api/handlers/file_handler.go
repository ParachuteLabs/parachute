package handlers

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/domain/file"
)

// FileHandler handles file-related HTTP requests
type FileHandler struct {
	fileService *file.Service
}

// NewFileHandler creates a new file handler
func NewFileHandler(fileService *file.Service) *FileHandler {
	return &FileHandler{
		fileService: fileService,
	}
}

// UploadCapture handles POST /api/captures/upload
func (h *FileHandler) UploadCapture(c fiber.Ctx) error {
	// Parse multipart form
	audioFile, err := c.FormFile("audio")
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "audio file is required")
	}

	// Parse timestamp
	timestampStr := c.FormValue("timestamp")
	if timestampStr == "" {
		return fiber.NewError(fiber.StatusBadRequest, "timestamp is required")
	}

	timestamp, err := time.Parse(time.RFC3339, timestampStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid timestamp format (use RFC3339)")
	}

	// Parse optional fields
	durationStr := c.FormValue("duration")
	duration := 0.0
	if durationStr != "" {
		duration, _ = strconv.ParseFloat(durationStr, 64)
	}

	source := c.FormValue("source")
	if source == "" {
		source = "unknown"
	}

	deviceID := c.FormValue("deviceId")

	// Open uploaded file
	fileReader, err := audioFile.Open()
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to open uploaded file")
	}
	defer fileReader.Close()

	// Save capture
	params := file.UploadCaptureParams{
		Timestamp: timestamp,
		Duration:  duration,
		Source:    source,
		DeviceID:  deviceID,
	}

	metadata, err := h.fileService.SaveCapture(fileReader, params)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to save capture: "+err.Error())
	}

	// TODO: Broadcast WebSocket event for real-time sync

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"id":        metadata.ID,
		"path":      "captures/" + metadata.Filename,
		"url":       "/api/captures/" + metadata.Filename,
		"createdAt": metadata.CreatedAt,
	})
}

// UploadTranscript handles POST /api/captures/:filename/transcript
func (h *FileHandler) UploadTranscript(c fiber.Ctx) error {
	filename := c.Params("filename")
	if filename == "" {
		return fiber.NewError(fiber.StatusBadRequest, "filename is required")
	}

	var data file.TranscriptData
	if err := c.Bind().JSON(&data); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}

	if data.Transcript == "" {
		return fiber.NewError(fiber.StatusBadRequest, "transcript is required")
	}

	if err := h.fileService.SaveTranscript(filename, data); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to save transcript: "+err.Error())
	}

	// TODO: Broadcast WebSocket event

	return c.JSON(fiber.Map{
		"success":        true,
		"transcriptPath": "captures/" + filename[:len(filename)-4] + ".md",
	})
}

// ListCaptures handles GET /api/captures
func (h *FileHandler) ListCaptures(c fiber.Ctx) error {
	// Parse pagination parameters
	limit := 50
	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 200 {
			limit = l
		}
	}

	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	captures, total, err := h.fileService.ListCaptures(limit, offset)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to list captures: "+err.Error())
	}

	return c.JSON(fiber.Map{
		"captures": captures,
		"total":    total,
		"limit":    limit,
		"offset":   offset,
		"hasMore":  offset+len(captures) < total,
	})
}

// DownloadCapture handles GET /api/captures/:filename
func (h *FileHandler) DownloadCapture(c fiber.Ctx) error {
	filename := c.Params("filename")
	if filename == "" {
		return fiber.NewError(fiber.StatusBadRequest, "filename is required")
	}

	// Get file reader
	fileReader, err := h.fileService.GetCapture(filename)
	if err != nil {
		return fiber.NewError(fiber.StatusNotFound, "capture not found")
	}
	defer fileReader.Close()

	// Set headers
	c.Set("Content-Type", "audio/wav")
	c.Set("Content-Disposition", "inline; filename=\""+filename+"\"")

	// Stream file
	return c.SendStream(fileReader)
}

// DownloadTranscript handles GET /api/captures/:filename/transcript
func (h *FileHandler) DownloadTranscript(c fiber.Ctx) error {
	filename := c.Params("filename")
	if filename == "" {
		return fiber.NewError(fiber.StatusBadRequest, "filename is required")
	}

	transcript, err := h.fileService.GetTranscript(filename)
	if err != nil {
		return fiber.NewError(fiber.StatusNotFound, "transcript not found")
	}

	// Set headers
	c.Set("Content-Type", "text/markdown; charset=utf-8")

	return c.SendString(transcript)
}

// DeleteCapture handles DELETE /api/captures/:filename
func (h *FileHandler) DeleteCapture(c fiber.Ctx) error {
	filename := c.Params("filename")
	if filename == "" {
		return fiber.NewError(fiber.StatusBadRequest, "filename is required")
	}

	if err := h.fileService.DeleteCapture(filename); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to delete capture: "+err.Error())
	}

	// TODO: Broadcast WebSocket event

	return c.JSON(fiber.Map{
		"success": true,
	})
}
