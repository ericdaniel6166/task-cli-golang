package cmd

import (
	"fmt"
	"os"
	"strconv"
	"task-cli/internal/task"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var priority int
var taskCmd = &cobra.Command{Use: "task", Short: "Task operations"}

// 'add' subcommand
var addCmd = &cobra.Command{
	Use:   "add [name]",
	Short: "Add a new task",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		author := viper.GetString("author")
		if err := task.SaveTask(args[0], priority, author); err != nil {
			fmt.Printf("Error: %v\n", err)
			return
		}
		fmt.Printf("Task '%s' added.\n", args[0])
	},
}

// 'list' subcommand
var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List all tasks",
	Run: func(cmd *cobra.Command, args []string) {
		tasks, err := task.GetAllTasks()
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			return
		}

		if len(tasks) == 0 {
			fmt.Println("No tasks found.")
			return
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', 0)
		fmt.Fprintln(w, "ID\tNAME\tPRIORITY\tAUTHOR")
		for _, t := range tasks {
			fmt.Fprintf(w, "%d\t%s\t%d\t%s\n", t.ID, t.Name, t.Priority, t.Author)
		}
		w.Flush()
	},
}

// 'delete' subcommand
var deleteCmd = &cobra.Command{
	Use:   "delete [id]",
	Short: "Delete a task by ID",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		id, err := strconv.Atoi(args[0])
		if err != nil {
			fmt.Printf("Error: Invalid task ID '%s'\n", args[0])
			return
		}
		if err := task.DeleteTask(id); err != nil {
			fmt.Printf("Error: %v\n", err)
			return
		}
		fmt.Printf("Task %d deleted.\n", id)
	},
}

// 'update' subcommand
var updateCmd = &cobra.Command{
	Use:   "update [id] [name]",
	Short: "Update a task's name and/or priority",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		id, err := strconv.Atoi(args[0])
		if err != nil {
			fmt.Printf("Error: Invalid task ID '%s'\n", args[0])
			return
		}
		if err := task.UpdateTask(id, args[1], priority); err != nil {
			fmt.Printf("Error: %v\n", err)
			return
		}
		fmt.Printf("Task %d updated.\n", id)
	},
}

func init() {
	RootCmd.AddCommand(taskCmd)
	taskCmd.AddCommand(addCmd)
	taskCmd.AddCommand(listCmd)
	taskCmd.AddCommand(deleteCmd)
	taskCmd.AddCommand(updateCmd)
	addCmd.Flags().IntVarP(&priority, "priority", "p", 1, "Task priority level")
	updateCmd.Flags().IntVarP(&priority, "priority", "p", 1, "Task priority level")
}
