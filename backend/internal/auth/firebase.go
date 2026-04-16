// Package auth handles Firebase token verification.
// Every API request from the Flutter app includes a Firebase ID token
// in the Authorization header. This package verifies that token is real,
// not expired, and belongs to a user who is allowed to use the system.
package auth

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	firebaseauth "firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// FirebaseClient wraps the Firebase Auth client.
type FirebaseClient struct {
	client *firebaseauth.Client
}

// NewFirebaseClient initializes the Firebase Admin SDK using the
// service account JSON file. This runs once at startup.
func NewFirebaseClient(serviceAccountPath string) (*FirebaseClient, error) {
	opt := option.WithCredentialsFile(serviceAccountPath)

	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Firebase app: %w", err)
	}

	client, err := app.Auth(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get Firebase Auth client: %w", err)
	}

	fmt.Println("✅ Firebase Auth client initialized")
	return &FirebaseClient{client: client}, nil
}

// VerifiedToken holds the claims extracted from a valid Firebase token.
// We use this to identify the user making each API request.
type VerifiedToken struct {
	UID         string // Firebase UID — unique per user
	Email       string
	DisplayName string
	PhotoURL    string
}

// VerifyIDToken checks that the token string is valid and not expired.
// Returns the token claims if valid, or an error if not.
func (f *FirebaseClient) VerifyIDToken(ctx context.Context, idToken string) (*VerifiedToken, error) {
	token, err := f.client.VerifyIDToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("invalid or expired token: %w", err)
	}

	// Extract user info from token claims
	email, _ := token.Claims["email"].(string)
	displayName, _ := token.Claims["name"].(string)
	photoURL, _ := token.Claims["picture"].(string)

	return &VerifiedToken{
		UID:         token.UID,
		Email:       email,
		DisplayName: displayName,
		PhotoURL:    photoURL,
	}, nil
}
