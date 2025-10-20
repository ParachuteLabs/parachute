package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v3"
)

func main() {
	app := fiber.New(fiber.Config{
		AppName: "Parachute Backend v1.0",
	})

	// Health check endpoint
	app.Get("/health", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"service": "parachute-backend",
			"version": "0.1.0",
		})
	})

	// API routes (placeholder)
	api := app.Group("/api")

	api.Get("/spaces", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"spaces": []string{},
		})
	})

	// Determine port
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Start server
	log.Printf("🚀 Parachute Backend starting on port %s", port)
	log.Printf("📍 Health check: http://localhost:%s/health", port)
	log.Fatal(app.Listen(":" + port))
}
