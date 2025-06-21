package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

// Product represents our data model
type Food struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Price int    `json:"price"`
}

var db *sql.DB

func main() {
	// Initialize database connection
	initDB()
	defer db.Close()

	// Create router
	r := mux.NewRouter()

	// Define routes
	r.HandleFunc("/api/foods", getFoods).Methods("GET")

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s...", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func initDB() {
	var err error

	connStr := os.Getenv("DATABASE_URL")
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}

	// Test the connection
	err = db.Ping()
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Successfully connected to database")
}

func getFoods(w http.ResponseWriter, r *http.Request) {
	// Query the database
	rows, err := db.Query("SELECT id, name, price FROM foods")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Iterate through results
	var foods []Food
	for rows.Next() {
		var p Food
		if err := rows.Scan(&p.ID, &p.Name, &p.Price); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		foods = append(foods, p)
	}

	// Check for errors from iterating over rows
	if err = rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Set content type and encode to JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(foods)
}
