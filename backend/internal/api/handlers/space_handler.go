package handlers

import (
	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/domain/space"
)

// SpaceHandler handles space-related HTTP requests
type SpaceHandler struct {
	service *space.Service
}

// NewSpaceHandler creates a new space handler
func NewSpaceHandler(service *space.Service) *SpaceHandler {
	return &SpaceHandler{service: service}
}

// List handles GET /api/spaces
func (h *SpaceHandler) List(c fiber.Ctx) error {
	ctx := c.Context()

	// TODO: Get user ID from auth context
	userID := "default"

	spaces, err := h.service.List(ctx, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to list spaces",
		})
	}

	// Ensure we always return an array, never null
	if spaces == nil {
		spaces = []*space.Space{}
	}

	return c.JSON(fiber.Map{
		"spaces": spaces,
	})
}

// Get handles GET /api/spaces/:id
func (h *SpaceHandler) Get(c fiber.Ctx) error {
	ctx := c.Context()
	id := c.Params("id")

	space, err := h.service.GetByID(ctx, id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Space not found",
		})
	}

	return c.JSON(space)
}

// Create handles POST /api/spaces
func (h *SpaceHandler) Create(c fiber.Ctx) error {
	ctx := c.Context()

	// Parse request body
	var params space.CreateSpaceParams
	if err := c.Bind().JSON(&params); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// TODO: Get user ID from auth context
	userID := "default"

	// Create space
	newSpace, err := h.service.Create(ctx, userID, params)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(newSpace)
}

// Update handles PUT /api/spaces/:id
func (h *SpaceHandler) Update(c fiber.Ctx) error {
	ctx := c.Context()
	id := c.Params("id")

	// Parse request body
	var params space.UpdateSpaceParams
	if err := c.Bind().JSON(&params); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Update space
	updatedSpace, err := h.service.Update(ctx, id, params)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(updatedSpace)
}

// Delete handles DELETE /api/spaces/:id
func (h *SpaceHandler) Delete(c fiber.Ctx) error {
	ctx := c.Context()
	id := c.Params("id")

	if err := h.service.Delete(ctx, id); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusNoContent).Send(nil)
}
