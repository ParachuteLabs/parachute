package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/domain"
)

// HandleError maps domain errors to appropriate HTTP responses
func HandleError(c fiber.Ctx, err error) error {
	// Check for domain-specific errors
	var notFoundErr *domain.NotFoundError
	if errors.As(err, &notFoundErr) {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": notFoundErr.Error(),
		})
	}

	var validationErr *domain.ValidationError
	if errors.As(err, &validationErr) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": validationErr.Error(),
			"field": validationErr.Field,
		})
	}

	var conflictErr *domain.ConflictError
	if errors.As(err, &conflictErr) {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"error": conflictErr.Error(),
		})
	}

	var unauthorizedErr *domain.UnauthorizedError
	if errors.As(err, &unauthorizedErr) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": unauthorizedErr.Error(),
		})
	}

	var forbiddenErr *domain.ForbiddenError
	if errors.As(err, &forbiddenErr) {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"error": forbiddenErr.Error(),
		})
	}

	// Default to internal server error
	return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
		"error": "Internal server error",
	})
}
