package registry_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/unforced/parachute-backend/internal/domain/registry"
	"github.com/unforced/parachute-backend/internal/storage/sqlite"
)

func TestRegistryService(t *testing.T) {
	// Create temporary directory for testing
	tmpDir, err := os.MkdirTemp("", "parachute-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create test database
	dbPath := filepath.Join(tmpDir, "test.db")
	db, err := sqlite.NewDatabase(dbPath)
	if err != nil {
		t.Fatalf("Failed to create database: %v", err)
	}
	defer db.Close()

	// Create registry repository and service
	repo := sqlite.NewRegistryRepository(db.DB)
	service := registry.NewService(repo, tmpDir)
	ctx := context.Background()

	t.Run("CreateSpace", func(t *testing.T) {
		spacePath := filepath.Join(tmpDir, "spaces", "test-space")
		space, err := service.CreateSpace(ctx, registry.CreateSpaceParams{
			Name: "Test Space",
			Path: spacePath,
		})
		if err != nil {
			t.Fatalf("Failed to create space: %v", err)
		}

		// Verify space was created
		if space.Name != "Test Space" {
			t.Errorf("Expected name 'Test Space', got '%s'", space.Name)
		}
		if space.Path != spacePath {
			t.Errorf("Expected path '%s', got '%s'", spacePath, space.Path)
		}

		// Verify directory exists
		if _, err := os.Stat(spacePath); os.IsNotExist(err) {
			t.Error("Space directory was not created")
		}

		// Verify agents.md exists
		agentsMD := filepath.Join(spacePath, "agents.md")
		if _, err := os.Stat(agentsMD); os.IsNotExist(err) {
			t.Error("agents.md was not created")
		}

		// Verify files/ directory exists
		filesDir := filepath.Join(spacePath, "files")
		if _, err := os.Stat(filesDir); os.IsNotExist(err) {
			t.Error("files/ directory was not created")
		}
	})

	t.Run("AddExistingSpace", func(t *testing.T) {
		// Create a directory with agents.md manually
		spacePath := filepath.Join(tmpDir, "external-space")
		if err := os.MkdirAll(spacePath, 0755); err != nil {
			t.Fatalf("Failed to create directory: %v", err)
		}
		agentsMD := filepath.Join(spacePath, "agents.md")
		if err := os.WriteFile(agentsMD, []byte("# External Space\n"), 0644); err != nil {
			t.Fatalf("Failed to create agents.md: %v", err)
		}

		// Add it to registry
		space, err := service.AddSpace(ctx, registry.AddSpaceParams{
			Path: spacePath,
			Name: "External Space",
		})
		if err != nil {
			t.Fatalf("Failed to add space: %v", err)
		}

		if space.Name != "External Space" {
			t.Errorf("Expected name 'External Space', got '%s'", space.Name)
		}
	})

	t.Run("ListSpaces", func(t *testing.T) {
		spaces, err := service.ListSpaces(ctx)
		if err != nil {
			t.Fatalf("Failed to list spaces: %v", err)
		}

		if len(spaces) < 2 {
			t.Errorf("Expected at least 2 spaces, got %d", len(spaces))
		}
	})

	t.Run("IsSpace", func(t *testing.T) {
		// Valid space with agents.md
		validPath := filepath.Join(tmpDir, "spaces", "test-space")
		if !service.IsSpace(validPath) {
			t.Error("Expected IsSpace to return true for valid space")
		}

		// Invalid space without agents.md
		invalidPath := filepath.Join(tmpDir, "not-a-space")
		if service.IsSpace(invalidPath) {
			t.Error("Expected IsSpace to return false for invalid space")
		}
	})

	t.Run("AddCapture", func(t *testing.T) {
		capture, err := service.AddCapture(ctx, registry.AddCaptureParams{
			BaseName:      "2025-10-29_test-recording",
			Title:         "Test Recording",
			HasAudio:      true,
			HasTranscript: true,
		})
		if err != nil {
			t.Fatalf("Failed to add capture: %v", err)
		}

		if capture.BaseName != "2025-10-29_test-recording" {
			t.Errorf("Expected base_name '2025-10-29_test-recording', got '%s'", capture.BaseName)
		}
		if capture.Title != "Test Recording" {
			t.Errorf("Expected title 'Test Recording', got '%s'", capture.Title)
		}
	})

	t.Run("GetCaptureByBaseName", func(t *testing.T) {
		capture, err := service.GetCaptureByBaseName(ctx, "2025-10-29_test-recording")
		if err != nil {
			t.Fatalf("Failed to get capture: %v", err)
		}

		if capture.Title != "Test Recording" {
			t.Errorf("Expected title 'Test Recording', got '%s'", capture.Title)
		}
	})

	t.Run("ListCaptures", func(t *testing.T) {
		captures, err := service.ListCaptures(ctx)
		if err != nil {
			t.Fatalf("Failed to list captures: %v", err)
		}

		if len(captures) < 1 {
			t.Error("Expected at least 1 capture")
		}
	})

	t.Run("Settings", func(t *testing.T) {
		// Get default setting
		notesFolder, err := service.GetSetting(ctx, "notes_folder")
		if err != nil {
			t.Fatalf("Failed to get setting: %v", err)
		}
		if notesFolder != "notes" {
			t.Errorf("Expected notes_folder to be 'notes', got '%s'", notesFolder)
		}

		// Set custom setting
		if err := service.SetSetting(ctx, "test_key", "test_value"); err != nil {
			t.Fatalf("Failed to set setting: %v", err)
		}

		// Get custom setting
		value, err := service.GetSetting(ctx, "test_key")
		if err != nil {
			t.Fatalf("Failed to get custom setting: %v", err)
		}
		if value != "test_value" {
			t.Errorf("Expected 'test_value', got '%s'", value)
		}
	})

	t.Run("GetNotesFolder", func(t *testing.T) {
		notesFolder := service.GetNotesFolder(ctx)
		expected := filepath.Join(tmpDir, "notes")
		if notesFolder != expected {
			t.Errorf("Expected notes folder '%s', got '%s'", expected, notesFolder)
		}
	})

	t.Run("GetSpacesFolder", func(t *testing.T) {
		spacesFolder := service.GetSpacesFolder(ctx)
		expected := filepath.Join(tmpDir, "spaces")
		if spacesFolder != expected {
			t.Errorf("Expected spaces folder '%s', got '%s'", expected, spacesFolder)
		}
	})
}
