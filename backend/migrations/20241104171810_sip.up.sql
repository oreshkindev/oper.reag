-- Create Racks table
CREATE TABLE
    IF NOT EXISTS sip (
        id BIGSERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT,
        transport TEXT,
        context TEXT NOT NULL,
        disallow TEXT,
        allow TEXT,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

-- Add unique constraints
ALTER TABLE sip ADD CONSTRAINT sip_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_sip_name ON sip (name);
