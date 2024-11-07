-- Create Permissions table
CREATE TABLE
    IF NOT EXISTS permissions (
        id BIGSERIAL PRIMARY KEY,
        description TEXT,
        name TEXT NOT NULL
    );

-- Add unique constraints
ALTER TABLE permissions ADD CONSTRAINT permissions_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_permissions_name ON permissions (name);

-- Seed
INSERT INTO
    permissions (description, name)
VALUES
    ('Гость', 'guest'),
    ('Оператор', 'operator'),
    ('Администратор', 'manager'),
    ('Инженер', 'engineer'),
    ('Разработчик', 'developer');
