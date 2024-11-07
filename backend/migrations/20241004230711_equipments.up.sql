-- Create Equipments table
CREATE TABLE
    IF NOT EXISTS equipments (
        id BIGSERIAL PRIMARY KEY,
        equipment_categories_id BIGINT REFERENCES equipment_categories (id) ON DELETE SET NULL,
        http TEXT,
        ip TEXT,
        model TEXT NOT NULL,
        name TEXT NOT NULL,
        racks_id BIGINT REFERENCES racks (id) ON DELETE SET NULL,
        serial_number TEXT,
        ssh TEXT,
        warranties_id BIGINT REFERENCES warranties (id) ON DELETE SET NULL,
        rtsp TEXT
    );

-- Add unique constraints
ALTER TABLE equipments ADD CONSTRAINT equipments_name_unique UNIQUE (name);

-- Create indexes
CREATE INDEX idx_equipment_categories ON equipments (equipment_categories_id);

CREATE INDEX idx_equipments_racks ON equipments (racks_id);

CREATE INDEX idx_equipments_warranties ON equipments (warranties_id);
