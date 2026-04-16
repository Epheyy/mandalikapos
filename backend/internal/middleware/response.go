package middleware

import (
	"encoding/json"
	"net/http"
)

// WriteJSON sends a JSON response with the given status code and data.
// All API handlers use this for consistent response formatting.
func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// WriteSuccess sends a 200 OK JSON response.
func WriteSuccess(w http.ResponseWriter, data any) {
	WriteJSON(w, http.StatusOK, data)
}

// WriteCreated sends a 201 Created JSON response.
func WriteCreated(w http.ResponseWriter, data any) {
	WriteJSON(w, http.StatusCreated, data)
}

// WriteNotFound sends a 404 Not Found JSON response.
func WriteNotFound(w http.ResponseWriter, message string) {
	WriteJSON(w, http.StatusNotFound, map[string]string{"error": message})
}

// WriteBadRequest sends a 400 Bad Request JSON response.
func WriteBadRequest(w http.ResponseWriter, message string) {
	WriteJSON(w, http.StatusBadRequest, map[string]string{"error": message})
}

// WriteInternalError sends a 500 Internal Server Error JSON response.
// We never send the raw Go error to clients — that would leak implementation details.
func WriteInternalError(w http.ResponseWriter, err error) {
	// Log the real error server-side
	println("Internal error:", err.Error())
	WriteJSON(w, http.StatusInternalServerError, map[string]string{
		"error": "an internal error occurred",
	})
}

// APIResponse is the standard envelope for all API responses.
type APIResponse struct {
	Data    any    `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

// WriteError sends a JSON error response with a given status code.
// This exported version is used by handlers.
func WriteError(w http.ResponseWriter, status int, message string) {
	WriteJSON(w, status, map[string]string{"error": message})
}
