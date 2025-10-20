package acp

import (
	"os"
	"testing"
	"time"
)

// TestACPIntegration tests the full ACP integration
// This is an integration test that requires:
// - ANTHROPIC_API_KEY environment variable
// - npx and @zed-industries/claude-code-acp installed
func TestACPIntegration(t *testing.T) {
	// Skip if no API key
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		t.Skip("ANTHROPIC_API_KEY not set, skipping integration test")
	}

	// Create client
	client, err := NewACPClient(apiKey)
	if err != nil {
		t.Fatalf("Failed to create ACP client: %v", err)
	}
	defer client.Close()

	// Test 1: Initialize
	t.Run("Initialize", func(t *testing.T) {
		result, err := client.Initialize()
		if err != nil {
			t.Fatalf("Initialize failed: %v", err)
		}

		t.Logf("Connected to %s v%s", result.ServerName, result.ServerVersion)

		if result.ServerName == "" {
			t.Error("ServerName is empty")
		}
	})

	// Test 2: Create Session
	t.Run("NewSession", func(t *testing.T) {
		sessionID, err := client.NewSession("/tmp", nil)
		if err != nil {
			t.Fatalf("NewSession failed: %v", err)
		}

		t.Logf("Created session: %s", sessionID)

		if sessionID == "" {
			t.Error("SessionID is empty")
		}
	})

	// Test 3: Send Prompt and Receive Response
	t.Run("SessionPrompt", func(t *testing.T) {
		// Create new session for this test
		sessionID, err := client.NewSession("/tmp", nil)
		if err != nil {
			t.Fatalf("NewSession failed: %v", err)
		}

		// Start listening for notifications
		notifications := client.Notifications()
		done := make(chan bool)
		receivedUpdate := false

		go func() {
			timeout := time.After(30 * time.Second)
			for {
				select {
				case notif := <-notifications:
					if notif.Method == "session/update" {
						update, err := ParseSessionUpdate(notif)
						if err != nil {
							t.Logf("Failed to parse update: %v", err)
							continue
						}

						if update.SessionID == sessionID {
							t.Logf("Received update for session %s", sessionID)
							receivedUpdate = true
							done <- true
							return
						}
					}
				case <-timeout:
					t.Log("Timeout waiting for response")
					done <- false
					return
				}
			}
		}()

		// Send prompt
		err = client.SessionPrompt(sessionID, "Say 'Hello from Parachute!' and nothing else.")
		if err != nil {
			t.Fatalf("SessionPrompt failed: %v", err)
		}

		// Wait for response
		success := <-done
		if !success {
			t.Error("Did not receive session/update notification")
		}
		if !receivedUpdate {
			t.Error("Did not receive update for our session")
		}
	})
}

// TestSpawnACP tests basic process spawning
func TestSpawnACP(t *testing.T) {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		t.Skip("ANTHROPIC_API_KEY not set, skipping test")
	}

	process, err := SpawnACP(apiKey)
	if err != nil {
		t.Fatalf("Failed to spawn ACP: %v", err)
	}
	defer process.Kill()

	// Check process is running
	if !process.IsRunning() {
		t.Error("Process is not running")
	}

	// Wait a bit
	time.Sleep(1 * time.Second)

	// Still running?
	if !process.IsRunning() {
		t.Error("Process died unexpectedly")
	}
}
