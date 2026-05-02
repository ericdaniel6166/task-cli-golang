package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"task-cli/internal/config"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var cfgFile string

// RootCmd is exported for documentation generation and main.go access
var RootCmd = &cobra.Command{
	Use:   "task-cli",
	Short: "Task-CLI: A professional task manager",
	Long:  `An extensible CLI tool using Go, supporting nested commands and kubectl-style plugins.`,
}

func Execute() {
	// Plugin Discovery: If the command is unknown, look for 'task-cli-<subcommand>' in PATH
	if len(os.Args) > 1 && !strings.HasPrefix(os.Args[1], "-") {
		_, _, err := RootCmd.Find(os.Args[1:])
		if err != nil {
			pluginName := fmt.Sprintf("task-cli-%s", os.Args[1])
			if path, err := exec.LookPath(pluginName); err == nil {
				invokePlugin(path, os.Args[2:])
				return
			}
		}
	}

	if err := RootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func invokePlugin(path string, args []string) {
	cmd := exec.Command(path, args...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(config.InitConfig(&cfgFile))
	RootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.task-cli.yaml)")
	RootCmd.PersistentFlags().StringP("author", "a", "Unknown", "Author for tasks")
	viper.BindPFlag("author", RootCmd.PersistentFlags().Lookup("author"))
}
