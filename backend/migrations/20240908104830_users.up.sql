-- Create Users table
CREATE TABLE
    IF NOT EXISTS users (
        id BIGSERIAL PRIMARY KEY,
        access_token TEXT,
        description TEXT,
        email TEXT NOT NULL,
        fullname TEXT NOT NULL,
        password TEXT NOT NULL,
        permissions_id BIGINT REFERENCES permissions (id) ON DELETE SET NULL,
        phone TEXT NOT NULL,
        position TEXT NOT NULL,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

-- Add unique constraints
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);

ALTER TABLE users ADD CONSTRAINT users_phone_unique UNIQUE (phone);

-- Create indexes
CREATE INDEX idx_users_email ON users (email);

CREATE INDEX idx_users_phone ON users (phone);

-- Seed
INSERT INTO
    users (
        access_token,
        description,
        email,
        fullname,
        password,
        permissions_id,
        phone,
        position
    )
VALUES
    (
        '',
        '',
        'example@example.com',
        'Гость',
        '$2a$10$WtsHqf0Pu1zU91QLSncKLO/ffn.2dFp0c5szz.uCTwEZyHTXAAdLu', -- 2p0f+9EGFWgCPvlJCQ
        4,
        '+70000000000',
        'Руководитель'
    )
