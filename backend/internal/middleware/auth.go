// Package middleware contains HTTP middleware functions.
// Middleware runs on every request BEFORE your handler function.
// Think of it as a security checkpoint at the door.
package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/Epheyy/mandalikapos/backend/internal/auth"
	"github.com/Epheyy/mandalikapos/backend/internal/database"
)

// contextKey is a private type for context keys to avoid collisions
// with other packages that also store values in context.
type contextKey string

const (
	// UserContextKey is the key used to store the verified user in request context.
	// Handlers retrieve the current user by reading this key from context.
	UserContextKey contextKey = "verified_user"
)

// RequireAuth is middleware that validates the Firebase token on every request.
// If the token is missing or invalid, it returns 401 immediately.
// If valid, it stores the user info in the request context so handlers can access it.
func RequireAuth(firebaseClient *auth.FirebaseClient) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// The Flutter app sends the token like:
			// Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				writeError(w, http.StatusUnauthorized, "missing Authorization header")
				return
			}

			// Split "Bearer <token>" and take just the token part
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				writeError(w, http.StatusUnauthorized, "Authorization header must be: Bearer <token>")
				return
			}

			token := parts[1]
			if token == "" {
				writeError(w, http.StatusUnauthorized, "token is empty")
				return
			}

			// Verify the token with Firebase
			verifiedUser, err := firebaseClient.VerifyIDToken(r.Context(), token)
			if err != nil {
				writeError(w, http.StatusUnauthorized, "invalid or expired token")
				return
			}

			// Store the verified user in the request context.
			// Handlers can now call GetUserFromContext(r) to get the current user.
			ctx := context.WithValue(r.Context(), UserContextKey, verifiedUser)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUserFromContext retrieves the verified user from the request context.
// Call this inside any handler that needs to know who is making the request.
func GetUserFromContext(r *http.Request) *auth.VerifiedToken {
	user, _ := r.Context().Value(UserContextKey).(*auth.VerifiedToken)
	return user
}

// writeError sends a JSON error response. Used internally by middleware.
func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

// RequireRole is middleware that checks the user has a specific role.
// Use after RequireAuth in the middleware chain.
// Example: the admin panel requires role "admin".
func RequireRole(db *database.DB, allowedRoles ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			verifiedUser := GetUserFromContext(r)
			if verifiedUser == nil {
				writeError(w, http.StatusUnauthorized, "not authenticated")
				return
			}

			// Look up the actual role from database
			var role string
			err := db.Pool.QueryRow(r.Context(),
				"SELECT role FROM users WHERE firebase_uid = $1 AND is_active = TRUE",
				verifiedUser.UID,
			).Scan(&role)
			if err != nil {
				writeError(w, http.StatusForbidden, "user not found or inactive")
				return
			}

			for _, allowed := range allowedRoles {
				if role == allowed {
					next.ServeHTTP(w, r)
					return
				}
			}

			writeError(w, http.StatusForbidden, "insufficient permissions")
		})
	}
}
