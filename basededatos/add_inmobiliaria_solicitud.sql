-- Agregar 'INMOBILIARIA' al enum tipo_solicitud
ALTER TABLE `solicitud` MODIFY COLUMN `tipo_solicitud` ENUM('COMPRA','ARRIENDO','INMOBILIARIA') NOT NULL;

-- Opcional: agregar índice para consultas por tipo
ALTER TABLE `solicitud` ADD INDEX `idx_tipo_solicitud` (`tipo_solicitud`);