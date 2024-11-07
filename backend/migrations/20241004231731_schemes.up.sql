-- Create Schemes table
CREATE TABLE
    IF NOT EXISTS schemes (
        id BIGSERIAL PRIMARY KEY,
        description TEXT,
        file TEXT NOT NULL,
        name TEXT NOT NULL
    );

-- Add unique constraints
ALTER TABLE schemes ADD CONSTRAINT schemes_name_unique UNIQUE (name);

ALTER TABLE schemes ADD CONSTRAINT schemes_file_unique UNIQUE (file);

-- Create indexes
CREATE INDEX idx_schemes_name ON schemes (name);
