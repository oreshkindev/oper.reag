-- Create Racks table
CREATE TABLE
    IF NOT EXISTS sip_aor (
        id BIGSERIAL PRIMARY KEY,
        sip_id BIGINT REFERENCES sip (id) ON DELETE SET NULL,
        type TEXT,
        max_contacts BIGINT DEFAULT NULL,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
