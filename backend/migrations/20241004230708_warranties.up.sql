-- Create Warranties table
CREATE TABLE
    IF NOT EXISTS warranties (id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL);

-- Add unique constraints
ALTER TABLE warranties ADD CONSTRAINT warranty_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_warranties_name ON warranties (name);

-- Seed
INSERT INTO
    warranties (name)
VALUES
    ('Без гарантии'),
    ('1 месяц'),
    ('3 месяца'),
    ('6 месяцев'),
    ('1 год'),
    ('2 года'),
    ('3 года'),
    ('5 лет'),
    ('10 лет'),
    ('Пожизненная гарантия');
