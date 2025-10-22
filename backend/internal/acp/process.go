package acp

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"
)

// ACPProcess manages the claude-code-acp subprocess
type ACPProcess struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout io.ReadCloser
	stderr io.ReadCloser
	mu     sync.Mutex
	done   chan struct{}
}

// SpawnACP spawns a new claude-code-acp subprocess
// apiKey: Optional Anthropic API key. If empty, the SDK will use OAuth credentials from macOS keychain or ~/.claude/.credentials.json
// Returns: *ACPProcess or error
func SpawnACP(apiKey string) (*ACPProcess, error) {
	// Create command
	cmd := exec.Command("npx", "@zed-industries/claude-code-acp")

	// Set environment variables
	// Only set ANTHROPIC_API_KEY if provided, otherwise SDK will use OAuth credentials
	if apiKey != "" {
		cmd.Env = append(os.Environ(),
			"ANTHROPIC_API_KEY="+apiKey,
		)
	} else {
		cmd.Env = os.Environ()
	}

	// Attach pipes
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stdin pipe: %w", err)
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stderr pipe: %w", err)
	}

	// Start process
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start claude-code-acp: %w", err)
	}

	process := &ACPProcess{
		cmd:    cmd,
		stdin:  stdin,
		stdout: stdout,
		stderr: stderr,
		done:   make(chan struct{}),
	}

	// Start stderr logger in background
	go process.logStderr()

	return process, nil
}

// logStderr logs stderr output from the subprocess
func (p *ACPProcess) logStderr() {
	scanner := bufio.NewScanner(p.stderr)
	for scanner.Scan() {
		// TODO: Use proper logger instead of fmt
		fmt.Fprintf(os.Stderr, "[ACP stderr] %s\n", scanner.Text())
	}
}

// Close gracefully shuts down the ACP process
func (p *ACPProcess) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	// Close stdin to signal process to exit
	if p.stdin != nil {
		p.stdin.Close()
	}

	// Wait for process to exit (with timeout would be better)
	if p.cmd != nil && p.cmd.Process != nil {
		if err := p.cmd.Wait(); err != nil {
			return fmt.Errorf("process exit error: %w", err)
		}
	}

	// Signal done
	close(p.done)

	return nil
}

// Kill forcefully terminates the ACP process
func (p *ACPProcess) Kill() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.cmd != nil && p.cmd.Process != nil {
		if err := p.cmd.Process.Kill(); err != nil {
			return fmt.Errorf("failed to kill process: %w", err)
		}
	}

	close(p.done)
	return nil
}

// IsRunning checks if the process is still running
func (p *ACPProcess) IsRunning() bool {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.cmd == nil || p.cmd.Process == nil {
		return false
	}

	// Check if process has exited
	select {
	case <-p.done:
		return false
	default:
		return true
	}
}
