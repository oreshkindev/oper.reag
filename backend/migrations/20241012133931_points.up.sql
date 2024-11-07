-- Create Point table
CREATE TABLE
    IF NOT EXISTS points (
        id BIGSERIAL PRIMARY KEY,
        equipment_categories_id BIGINT REFERENCES equipment_categories (id) ON DELETE SET NULL,
        equipments_id BIGINT REFERENCES equipments (id) ON DELETE SET NULL,
        point_positions_id BIGINT REFERENCES point_positions (id) ON DELETE SET NULL,
        schemes_id BIGINT REFERENCES schemes (id) ON DELETE SET NULL
    );

-- Add indexes
CREATE INDEX idx_points_equipment_categories ON points (equipment_categories_id);

CREATE INDEX idx_points_equipments ON points (equipments_id);

CREATE INDEX idx_points_point_positions ON points (point_positions_id);

CREATE INDEX idx_points_schemes ON points (schemes_id);
