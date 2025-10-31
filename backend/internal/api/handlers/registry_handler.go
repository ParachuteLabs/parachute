package handlers

import (
	"log/slog"

	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/domain/registry"
)

// RegistryHandler handles HTTP requests for registry operations
type RegistryHandler struct {
	registryService *registry.Service
}

// NewRegistryHandler creates a new registry handler
func NewRegistryHandler(registryService *registry.Service) *RegistryHandler {
	return &RegistryHandler{
		registryService: registryService,
	}
}

// ListSpaces returns all registered spaces
// GET /api/registry/spaces
func (h *RegistryHandler) ListSpaces(c fiber.Ctx) error {
	spaces, err := h.registryService.ListSpaces(c.Context())
	if err != nil {
		slog.Error("Failed to list spaces", "error", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to list spaces",
		})
	}

	// Ensure we always return an array, never null
	if spaces == nil {
		spaces = []*registry.Space{}
	}

	return c.JSON(fiber.Map{
		"spaces": spaces,
	})
}

// AddSpace registers an existing directory as a space
// POST /api/registry/spaces/add
// Body: {"path": "/path/to/space", "name": "Optional Name", "config": "{}"}
func (h *RegistryHandler) AddSpace(c fiber.Ctx) error {
	var params registry.AddSpaceParams
	if err := c.Bind().JSON(&params); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if params.Path == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "path is required",
		})
	}

	space, err := h.registryService.AddSpace(c.Context(), params)
	if err != nil {
		slog.Error("Failed to add space", "error", err, "path", params.Path)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(space)
}

// CreateSpace creates a new space directory with agents.md
// POST /api/registry/spaces/create
// Body: {"name": "Space Name", "path": "/path/to/create", "config": "{}"}
func (h *RegistryHandler) CreateSpace(c fiber.Ctx) error {
	var params registry.CreateSpaceParams
	if err := c.Bind().JSON(&params); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if params.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "name is required",
		})
	}
	if params.Path == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "path is required",
		})
	}

	space, err := h.registryService.CreateSpace(c.Context(), params)
	if err != nil {
		slog.Error("Failed to create space", "error", err, "name", params.Name)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(space)
}

// GetSpace retrieves a space by ID
// GET /api/registry/spaces/:id
func (h *RegistryHandler) GetSpace(c fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "space ID is required",
		})
	}

	space, err := h.registryService.GetSpaceByID(c.Context(), id)
	if err != nil {
		slog.Error("Failed to get space", "error", err, "id", id)
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Space not found",
		})
	}

	return c.JSON(space)
}

// RemoveSpace removes a space from the registry (doesn't delete folder)
// DELETE /api/registry/spaces/:id
func (h *RegistryHandler) RemoveSpace(c fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "space ID is required",
		})
	}

	if err := h.registryService.RemoveSpace(c.Context(), id); err != nil {
		slog.Error("Failed to remove space", "error", err, "id", id)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to remove space",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Space removed from registry (folder not deleted)",
	})
}

// ListCaptures returns all registered captures
// GET /api/registry/captures
func (h *RegistryHandler) ListCaptures(c fiber.Ctx) error {
	captures, err := h.registryService.ListCaptures(c.Context())
	if err != nil {
		slog.Error("Failed to list captures", "error", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to list captures",
		})
	}

	// Ensure we always return an array, never null
	if captures == nil {
		captures = []*registry.Capture{}
	}

	return c.JSON(fiber.Map{
		"captures": captures,
	})
}

// AddCapture registers a new capture/note
// POST /api/registry/captures
// Body: {"base_name": "2025-10-29_soil-health", "title": "Soil Health Discussion", "has_audio": true, "has_transcript": true}
func (h *RegistryHandler) AddCapture(c fiber.Ctx) error {
	var params registry.AddCaptureParams
	if err := c.Bind().JSON(&params); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if params.BaseName == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "base_name is required",
		})
	}

	capture, err := h.registryService.AddCapture(c.Context(), params)
	if err != nil {
		slog.Error("Failed to add capture", "error", err, "base_name", params.BaseName)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(capture)
}

// GetCapture retrieves a capture by ID
// GET /api/registry/captures/:id
func (h *RegistryHandler) GetCapture(c fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "capture ID is required",
		})
	}

	capture, err := h.registryService.GetCaptureByID(c.Context(), id)
	if err != nil {
		slog.Error("Failed to get capture", "error", err, "id", id)
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Capture not found",
		})
	}

	return c.JSON(capture)
}

// GetSettings returns all settings
// GET /api/registry/settings
func (h *RegistryHandler) GetSettings(c fiber.Ctx) error {
	// Return commonly used settings
	notesFolder := h.registryService.GetNotesFolder(c.Context())
	spacesFolder := h.registryService.GetSpacesFolder(c.Context())

	return c.JSON(fiber.Map{
		"notes_folder":  notesFolder,
		"spaces_folder": spacesFolder,
	})
}

// SetSetting updates a setting
// PUT /api/registry/settings/:key
// Body: {"value": "new-value"}
func (h *RegistryHandler) SetSetting(c fiber.Ctx) error {
	key := c.Params("key")
	if key == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "setting key is required",
		})
	}

	var body struct {
		Value string `json:"value"`
	}
	if err := c.Bind().JSON(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if body.Value == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "value is required",
		})
	}

	if err := h.registryService.SetSetting(c.Context(), key, body.Value); err != nil {
		slog.Error("Failed to set setting", "error", err, "key", key)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to update setting",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"key":     key,
		"value":   body.Value,
	})
}
