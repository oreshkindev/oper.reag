-- Create Racks table
CREATE TABLE
    IF NOT EXISTS racks (
        id BIGSERIAL PRIMARY KEY,
        description TEXT,
        location TEXT NOT NULL,
        name TEXT NOT NULL,
        units BIGINT DEFAULT NULL
    );

-- Add unique constraints
ALTER TABLE racks ADD CONSTRAINT racks_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_racks_name ON racks (name);
