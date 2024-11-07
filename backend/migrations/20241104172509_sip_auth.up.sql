-- Create Racks table
CREATE TABLE
    IF NOT EXISTS sip_auth (
        id BIGSERIAL PRIMARY KEY,
        sip_id BIGINT REFERENCES sip (id) ON DELETE SET NULL,
        type TEXT,
        auth_type TEXT,
        password TEXT NOT NULL,
        username TEXT NOT NULL,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
