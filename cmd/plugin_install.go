package cmd

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var pluginCmd = &cobra.Command{Use: "plugin", Short: "Plugin management"}

var installCmd = &cobra.Command{
	Use:   "install [url] [name]",
	Short: "Install a plugin from a URL",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		downloadURL, pluginName := args[0], args[1]

		// Validate URL
		parsedURL, err := url.Parse(downloadURL)
		if err != nil {
			fmt.Printf("Invalid URL: %v\n", err)
			return
		}
		if parsedURL.Scheme != "https" {
			fmt.Printf("Security Error: Only HTTPS URLs are allowed\n")
			return
		}

		// Validate plugin name (prevent path traversal)
		if strings.Contains(pluginName, "/") || strings.Contains(pluginName, "\\") || strings.Contains(pluginName, "..") {
			fmt.Printf("Invalid plugin name: must not contain path separators\n")
			return
		}

		fullName := "task-cli-" + pluginName
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Printf("Error getting home directory: %v\n", err)
			return
		}
		binDir := filepath.Join(home, ".task-cli", "bin")

		if err := os.MkdirAll(binDir, 0755); err != nil {
			fmt.Printf("FS Error: %v\n", err)
			return
		}

		// Download with size limit (100MB)
		resp, err := http.Get(downloadURL)
		if err != nil {
			fmt.Printf("Network Error: %v\n", err)
			return
		}
		defer resp.Body.Close()

		// Check HTTP status
		if resp.StatusCode != http.StatusOK {
			fmt.Printf("Download failed: HTTP %d %s\n", resp.StatusCode, resp.Status)
			return
		}

		// Check content length if available
		const maxSize = 100 * 1024 * 1024 // 100MB
		if resp.ContentLength > maxSize {
			fmt.Printf("File too large: %d bytes (max %d)\n", resp.ContentLength, maxSize)
			return
		}

		dest := filepath.Join(binDir, fullName)
		out, err := os.Create(dest)
		if err != nil {
			fmt.Printf("Creation Error: %v\n", err)
			return
		}

		// Use LimitReader to enforce size limit during download
		limitedReader := io.LimitReader(resp.Body, maxSize+1)
		written, err := io.Copy(out, limitedReader)
		out.Close()

		if err != nil {
			os.Remove(dest) // Clean up partial download
			fmt.Printf("Download Error: %v\n", err)
			return
		}

		if written > maxSize {
			os.Remove(dest)
			fmt.Printf("File too large: exceeded %d bytes\n", maxSize)
			return
		}

		if err := os.Chmod(dest, 0755); err != nil {
			fmt.Printf("Warning: Could not set executable permissions: %v\n", err)
		}

		fmt.Printf("Installed %s to %s\n", fullName, binDir)
	},
}

func init() {
	RootCmd.AddCommand(pluginCmd)
	pluginCmd.AddCommand(installCmd)
}
