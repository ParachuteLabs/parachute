package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/api/handlers"
	"github.com/unforced/parachute-backend/internal/domain/space"
	"github.com/unforced/parachute-backend/internal/storage/sqlite"
)

func main() {
	// Get configuration from environment
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbPath := os.Getenv("DATABASE_PATH")
	if dbPath == "" {
		dbPath = "./data/parachute.db"
	}

	// Initialize database
	log.Println("📦 Connecting to database...")
	db, err := sqlite.NewDatabase(dbPath)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()
	log.Println("✅ Database connected and migrations applied")

	// Initialize repositories
	spaceRepo := sqlite.NewSpaceRepository(db.DB)
	conversationRepo := sqlite.NewConversationRepository(db.DB)

	// Initialize services
	spaceService := space.NewService(spaceRepo)

	// Initialize handlers
	spaceHandler := handlers.NewSpaceHandler(spaceService)

	// Create Fiber app
	app := fiber.New(fiber.Config{
		AppName: "Parachute Backend v1.0",
	})

	// Middleware
	app.Use(func(c fiber.Ctx) error {
		log.Printf("%s %s", c.Method(), c.Path())
		return c.Next()
	})

	// Health check endpoint
	app.Get("/health", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"service": "parachute-backend",
			"version": "0.1.0",
		})
	})

	// API routes
	api := app.Group("/api")

	// Space routes
	spaces := api.Group("/spaces")
	spaces.Get("/", spaceHandler.List)
	spaces.Post("/", spaceHandler.Create)
	spaces.Get("/:id", spaceHandler.Get)
	spaces.Put("/:id", spaceHandler.Update)
	spaces.Delete("/:id", spaceHandler.Delete)

	// Conversation routes (placeholder)
	conversations := api.Group("/conversations")
	conversations.Get("/", func(c fiber.Ctx) error {
		spaceID := c.Query("space_id")
		if spaceID == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "space_id query parameter required",
			})
		}

		convs, err := conversationRepo.ListConversations(c.Context(), spaceID)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to list conversations",
			})
		}

		return c.JSON(fiber.Map{
			"conversations": convs,
		})
	})

	// Start server
	log.Printf("🚀 Parachute Backend starting on port %s", port)
	log.Printf("📍 Health check: http://localhost:%s/health", port)
	log.Printf("📍 API endpoints: http://localhost:%s/api/*", port)
	log.Fatal(app.Listen(":" + port))
}
