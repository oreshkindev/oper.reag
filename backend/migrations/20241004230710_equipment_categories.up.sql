-- Create Equipment_categories table
CREATE TABLE
    IF NOT EXISTS equipment_categories (
        id BIGSERIAL PRIMARY KEY,
        description TEXT,
        name TEXT NOT NULL
    );

-- Add unique constraints
ALTER TABLE equipment_categories ADD CONSTRAINT equipment_categories_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_equipment_categories_name ON equipment_categories (name);
