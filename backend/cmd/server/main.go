package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/unforced/parachute-backend/internal/acp"
	"github.com/unforced/parachute-backend/internal/api/handlers"
	"github.com/unforced/parachute-backend/internal/domain/conversation"
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

	apiKey := os.Getenv("ANTHROPIC_API_KEY")

	// Initialize database
	log.Println("📦 Connecting to database...")
	db, err := sqlite.NewDatabase(dbPath)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()
	log.Println("✅ Database connected and migrations applied")

	// Initialize ACP client
	// If ANTHROPIC_API_KEY is not set, the SDK will use OAuth credentials from macOS keychain
	log.Println("🤖 Initializing ACP client...")
	if apiKey == "" {
		log.Println("ℹ️  No ANTHROPIC_API_KEY provided, using Claude OAuth credentials from system keychain")
	}

	acpClient, err := acp.NewACPClient(apiKey)
	if err != nil {
		log.Printf("⚠️  Failed to initialize ACP client: %v", err)
		log.Println("⚠️  Continuing without ACP integration")
		acpClient = nil
	} else if acpClient != nil {
		defer acpClient.Close()

		// Initialize ACP connection
		result, err := acpClient.Initialize()
		if err != nil {
			log.Printf("⚠️  Failed to initialize ACP: %v", err)
			log.Println("⚠️  Continuing without ACP integration")
			acpClient.Close()
			acpClient = nil
		} else {
			log.Printf("✅ Connected to %s v%s", result.ServerName, result.ServerVersion)
		}
	}

	// Initialize repositories
	spaceRepo := sqlite.NewSpaceRepository(db.DB)
	conversationRepo := sqlite.NewConversationRepository(db.DB)

	// Initialize services
	spaceService := space.NewService(spaceRepo)
	conversationService := conversation.NewService(conversationRepo)

	// Initialize handlers
	spaceHandler := handlers.NewSpaceHandler(spaceService)
	// Message handler works with or without ACP (acpClient can be nil)
	messageHandler := handlers.NewMessageHandler(conversationService, spaceService, acpClient)

	var wsHandler *handlers.WebSocketHandler
	if acpClient != nil {
		wsHandler = handlers.NewWebSocketHandler(acpClient)
	}

	// Create Fiber app
	app := fiber.New(fiber.Config{
		AppName: "Parachute Backend v1.0",
	})

	// Middleware
	app.Use(cors.New(cors.Config{
		AllowOrigins: []string{"*"},
		AllowHeaders: []string{"Origin", "Content-Type", "Accept"},
	}))

	app.Use(func(c fiber.Ctx) error {
		log.Printf("%s %s", c.Method(), c.Path())
		return c.Next()
	})

	// Health check endpoint
	app.Get("/health", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":       "ok",
			"service":      "parachute-backend",
			"version":      "0.1.0",
			"acp_enabled":  acpClient != nil,
		})
	})

	// WebSocket endpoint
	if wsHandler != nil {
		app.Get("/ws", wsHandler.HandleUpgrade())
		log.Println("✅ WebSocket endpoint enabled: ws://localhost:" + port + "/ws")
	}

	// API routes
	api := app.Group("/api")

	// Space routes
	spaces := api.Group("/spaces")
	spaces.Get("/", spaceHandler.List)
	spaces.Post("/", spaceHandler.Create)
	spaces.Get("/:id", spaceHandler.Get)
	spaces.Put("/:id", spaceHandler.Update)
	spaces.Delete("/:id", spaceHandler.Delete)

	// Conversation routes
	conversations := api.Group("/conversations")
	conversations.Get("/", func(c fiber.Ctx) error {
		spaceID := c.Query("space_id")
		if spaceID == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "space_id query parameter required",
			})
		}

		convs, err := conversationService.ListConversations(c.Context(), spaceID)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to list conversations",
			})
		}

		// Ensure we always return an array, never null
		if convs == nil {
			convs = []*conversation.Conversation{}
		}

		return c.JSON(fiber.Map{
			"conversations": convs,
		})
	})

	conversations.Post("/", func(c fiber.Ctx) error {
		var params conversation.CreateConversationParams
		if err := c.Bind().JSON(&params); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid request body",
			})
		}

		conv, err := conversationService.CreateConversation(c.Context(), params)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": err.Error(),
			})
		}

		return c.Status(fiber.StatusCreated).JSON(conv)
	})

	// Message routes
	messages := api.Group("/messages")
	messages.Get("/", messageHandler.ListMessages)
	messages.Post("/", messageHandler.SendMessage)

	// Start server
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("🚀 Parachute Backend v1.0 starting on port %s", port)
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("📍 Health:  http://localhost:%s/health", port)
	log.Printf("📍 API:     http://localhost:%s/api/*", port)
	if wsHandler != nil {
		log.Printf("📍 WebSocket: ws://localhost:%s/ws", port)
	}
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	log.Fatal(app.Listen(":" + port))
}
