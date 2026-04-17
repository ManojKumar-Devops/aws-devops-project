-- Initialize application database schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS items (
    id          SERIAL PRIMARY KEY,
    uuid        UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_items_uuid ON items(uuid);
CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at DESC);

-- Seed data for testing
INSERT INTO items (name, description) VALUES
    ('Sample Item 1', 'This is a sample item for testing'),
    ('Sample Item 2', 'Another sample item'),
    ('Sample Item 3', 'Third sample item')
ON CONFLICT DO NOTHING;
