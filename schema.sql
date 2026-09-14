-- Archery Scoring Database Schema
CREATE DATABASE IF NOT EXISTS archery_scoring_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE archery_scoring_db;

-- 1. Athletes
CREATE TABLE IF NOT EXISTS athletes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    athlete_code VARCHAR(100) UNIQUE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Scoring Sessions
CREATE TABLE IF NOT EXISTS scoring_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    athlete_id INT NOT NULL,
    bow_category ENUM('Recurve', 'Compound', 'Barebow', 'Standard Bow / National') NOT NULL,
    session_type ENUM('training', 'competition') NOT NULL DEFAULT 'training',
    distance VARCHAR(50) NOT NULL DEFAULT '18m',
    arrows_per_end INT NOT NULL DEFAULT 6,
    total_ends INT NOT NULL DEFAULT 10,
    current_end INT NOT NULL DEFAULT 1,
    status ENUM('in_progress', 'completed', 'abandoned') NOT NULL DEFAULT 'in_progress',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_athlete (athlete_id),
    INDEX idx_status (status),
    FOREIGN KEY (athlete_id) REFERENCES athletes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3. Scoring Ends
CREATE TABLE IF NOT EXISTS scoring_ends (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    end_number INT NOT NULL,
    total_score INT NOT NULL DEFAULT 0,
    x_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_session_end (session_id, end_number),
    INDEX idx_session (session_id),
    FOREIGN KEY (session_id) REFERENCES scoring_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4. Arrow Scores
CREATE TABLE IF NOT EXISTS arrow_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    end_id INT NOT NULL,
    arrow_number INT NOT NULL,
    score INT NOT NULL,
    is_x BOOLEAN NOT NULL DEFAULT FALSE,
    source ENUM('manual', 'ai') NOT NULL DEFAULT 'manual',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_end_arrow (end_id, arrow_number),
    INDEX idx_end (end_id),
    FOREIGN KEY (end_id) REFERENCES scoring_ends(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Legacy tables preserved for existing prototype endpoints
CREATE TABLE IF NOT EXISTS `range` (
    rangeID INT AUTO_INCREMENT PRIMARY KEY,
    rangeTotalArrowsPerEnd INT NOT NULL DEFAULT 6,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS arrowStaging (
    id INT AUTO_INCREMENT PRIMARY KEY,
    roundID INT NOT NULL,
    participationID INT NOT NULL,
    distance VARCHAR(50) NOT NULL,
    endOrder INT NOT NULL,
    arrowScore INT NOT NULL,
    isX TINYINT NOT NULL DEFAULT 0,
    stagingStatus VARCHAR(50) NOT NULL DEFAULT 'pending',
    date DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
