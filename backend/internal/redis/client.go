// Package redis manages the Redis connection and provides
// helper methods for caching. Redis stores frequently-read data
// in memory so we don't hit PostgreSQL for every request.
// Example: product list is cached for 5 minutes — 100 cashiers
// reading products = 1 DB query instead of 100.
package redis

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps the Redis client with typed helper methods.
type Client struct {
	rdb *redis.Client
}

// New creates a new Redis client and verifies the connection.
func New(redisURL string) (*Client, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse Redis URL: %w", err)
	}

	rdb := redis.NewClient(opts)

	// Verify connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	fmt.Println("✅ Connected to Redis successfully")
	return &Client{rdb: rdb}, nil
}

// Close shuts down the Redis connection cleanly.
func (c *Client) Close() error {
	return c.rdb.Close()
}

// Set stores any value as JSON with an expiration time.
// key: a string identifier like "products:all" or "products:category:abc123"
// value: anything — it gets serialized to JSON automatically
// ttl: how long before the cache expires (e.g. 5*time.Minute)
func (c *Client) Set(ctx context.Context, key string, value any, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to serialize value for key %s: %w", key, err)
	}
	return c.rdb.Set(ctx, key, data, ttl).Err()
}

// Get retrieves a cached value and deserializes it into dest.
// Returns ErrCacheMiss if the key doesn't exist or has expired.
func (c *Client) Get(ctx context.Context, key string, dest any) error {
	data, err := c.rdb.Get(ctx, key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return ErrCacheMiss
		}
		return fmt.Errorf("failed to get key %s: %w", key, err)
	}
	return json.Unmarshal(data, dest)
}

// Delete removes one or more keys from the cache.
// Call this whenever you update data that is cached,
// so the next read gets fresh data from the database.
func (c *Client) Delete(ctx context.Context, keys ...string) error {
	return c.rdb.Del(ctx, keys...).Err()
}

// DeleteByPattern removes all keys matching a pattern.
// Example: DeleteByPattern(ctx, "products:*") clears all product caches.
func (c *Client) DeleteByPattern(ctx context.Context, pattern string) error {
	keys, err := c.rdb.Keys(ctx, pattern).Result()
	if err != nil {
		return err
	}
	if len(keys) == 0 {
		return nil
	}
	return c.rdb.Del(ctx, keys...).Err()
}

// HealthCheck verifies Redis is still reachable.
func (c *Client) HealthCheck(ctx context.Context) error {
	return c.rdb.Ping(ctx).Err()
}

// ErrCacheMiss is returned when a key is not found in cache.
// Callers check for this to know they need to fetch from the database.
var ErrCacheMiss = fmt.Errorf("cache miss")
