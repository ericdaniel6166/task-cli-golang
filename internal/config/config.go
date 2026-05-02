package config

import (
	"os"

	"github.com/spf13/viper"
)

func InitConfig(cfgFile *string) func() {
	return func() {
		if *cfgFile != "" {
			viper.SetConfigFile(*cfgFile)
		} else {
			// Check TASK_CLI_DATA_DIR first, then default
			dataDir := os.Getenv("TASK_CLI_DATA_DIR")
			if dataDir == "" {
				home, err := os.UserHomeDir()
				if err != nil {
					// Fallback to current directory if home dir unavailable
					dataDir = "."
				} else {
					dataDir = home
				}
			}
			viper.AddConfigPath(dataDir)
			viper.SetConfigName(".task-cli")
			viper.SetConfigType("yaml")
		}
		viper.AutomaticEnv()
		// Config file is optional, ignore read errors
		_ = viper.ReadInConfig()
	}
}
