package task

import (
	"fmt"
	"task-cli/internal/database"
)

type Task struct {
	ID       int
	Name     string
	Priority int
	Author   string
}

func SaveTask(name string, priority int, author string) error {
	_, err := database.DB.Exec(
		"INSERT INTO tasks (name, priority, author) VALUES (?, ?, ?)",
		name, priority, author,
	)
	return err
}

func GetAllTasks() ([]Task, error) {
	rows, err := database.DB.Query("SELECT id, name, priority, author FROM tasks")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []Task
	for rows.Next() {
		var t Task
		if err := rows.Scan(&t.ID, &t.Name, &t.Priority, &t.Author); err != nil {
			return nil, err
		}
		tasks = append(tasks, t)
	}
	return tasks, nil
}

func DeleteTask(id int) error {
	result, err := database.DB.Exec("DELETE FROM tasks WHERE id = ?", id)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("task %d not found", id)
	}
	return nil
}

func UpdateTask(id int, name string, priority int) error {
	result, err := database.DB.Exec(
		"UPDATE tasks SET name = ?, priority = ? WHERE id = ?",
		name, priority, id,
	)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("task %d not found", id)
	}
	return nil
}
