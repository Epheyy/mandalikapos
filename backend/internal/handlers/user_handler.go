// Package handlers contains HTTP handler functions.
// Handlers read the request, call a service, and write the response.
// They should NOT contain business logic — that belongs in services.
package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
	"github.com/google/uuid"
)

// UserHandler handles HTTP requests related to users.
type UserHandler struct {
	userService *services.UserService
}

// NewUserHandler creates a new UserHandler.
func NewUserHandler(userService *services.UserService) *UserHandler {
	return &UserHandler{userService: userService}
}

// Me returns the currently authenticated user's profile.
// This is the first endpoint Flutter calls after login to get user data.
// POST /api/v1/auth/me
func (h *UserHandler) Me(w http.ResponseWriter, r *http.Request) {
	// Get the verified Firebase user from the request context
	// (set by the RequireAuth middleware)
	verifiedUser := middleware.GetUserFromContext(r)
	if verifiedUser == nil {
		middleware.WriteError(w, http.StatusUnauthorized, "not authenticated")
		return
	}

	// Look up or create this user in our PostgreSQL database
	user, err := h.userService.GetOrCreateByFirebaseUID(
		r.Context(),
		verifiedUser.UID,
		verifiedUser.Email,
		verifiedUser.DisplayName,
		verifiedUser.PhotoURL,
	)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}

	middleware.WriteSuccess(w, user)
}

// ListUsers returns all users (admin only).
// GET /api/v1/users
func (h *UserHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	users, err := h.userService.GetAllUsers(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, users)
}

// UpdateUser changes a user's role and permissions (admin only).
// PATCH /api/v1/users/{id}
func (h *UserHandler) UpdateUser(w http.ResponseWriter, r *http.Request) {
	// Parse the user ID from the URL path
	idStr := r.PathValue("id")
	userID, err := uuid.Parse(idStr)
	if err != nil {
		middleware.WriteBadRequest(w, "invalid user ID format")
		return
	}

	// Parse the request body
	var body struct {
		Role        string   `json:"role"`
		Permissions []string `json:"permissions"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	if err := h.userService.UpdateUserRole(r.Context(), userID, body.Role, body.Permissions); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}

	// Return the updated user
	user, err := h.userService.GetByID(r.Context(), userID)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}

	middleware.WriteSuccess(w, user)
}
