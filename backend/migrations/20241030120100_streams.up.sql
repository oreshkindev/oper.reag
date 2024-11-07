-- Create Racks table
CREATE TABLE
    IF NOT EXISTS streams (id BIGSERIAL PRIMARY KEY, url TEXT, playlist TEXT);

-- Add unique constraints
ALTER TABLE streams ADD CONSTRAINT streams_url_unique UNIQUE (url);

-- Create indexes
CREATE INDEX idx_streams_url ON streams (url);

CREATE INDEX idx_streams_playlist ON streams (playlist);
