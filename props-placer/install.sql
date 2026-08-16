-- À exécuter uniquement si Config.Storage = 'mysql'.
-- Le backend 'json' (par défaut) ne nécessite aucune base de données.

CREATE TABLE IF NOT EXISTS `placed_props` (
    `id`         VARCHAR(36)  NOT NULL,
    `model`      VARCHAR(64)  NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `rx`         FLOAT        NOT NULL DEFAULT 0,
    `ry`         FLOAT        NOT NULL DEFAULT 0,
    `rz`         FLOAT        NOT NULL DEFAULT 0,
    `owner`      VARCHAR(64)  DEFAULT NULL,
    `owner_name` VARCHAR(64)  DEFAULT NULL,
    `created_at` INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
