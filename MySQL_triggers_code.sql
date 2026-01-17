-- BEFORE TRIGGERS

/* I. Create a daily limit trigger
	1. Calculate sum of all transactions per day
	2. Check if Sum <= Daily limit */

DELIMITER $$
DROP TRIGGER IF EXISTS trg_enforce_daily_limit $$
CREATE TRIGGER trg_enforce_daily_limit
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE v_daily_limit DECIMAL(12,2);
	DECLARE v_todays_total DECIMAL(12,2);
    
	-- Get daily limit
		SELECT daily_txn_limit
        INTO v_daily_limit
        FROM accounts
        WHERE account_id = NEW.account_id;
        
    -- Calculate today's total
		SELECT COALESCE(SUM(amount),0)
        INTO v_todays_total
        FROM transactions
        WHERE account_id = NEW.account_id AND
			DATE(txn_timestamp) = DATE(NEW.txn_timestamp);
    
    -- Compare Daily limit vs Today's total
		IF v_todays_total + NEW.amount > v_daily_limit THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Daily transaction limit reached. Please try tomorrow';
		END IF;

END $$
DELIMITER ;


/* II. Validation trigger
	1. Disable Transacting ability for frozen accounts
    2. Not allowing Negative transactions */
    
DELIMITER $$
DROP TRIGGER IF EXISTS trg_validate_account_and_amount $$
CREATE TRIGGER trg_validate_account_and_amount
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE v_account_status VARCHAR(20);
    
	-- Amount must be +ve
    IF 
		NEW.amount < 0 THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Transaction amount must be greater than 0';
	END IF;
        
    -- Fetch account status
    SELECT account_status
    INTO v_account_status
    FROM accounts
    WHERE account_id = NEW.account_id;

    -- Only active accounts should be able to transact
	IF
		v_account_status <> 'ACTIVE' THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Transaction denied. Account is frozen';
	END IF;
END $$
DELIMITER ;

-- AFTER TRIGGERS

/* I. Create Velocity trigger function
	More than 3 transactions in 2 minutes */

-- Create fraud alert table

SELECT * FROM customers;
SELECT * FROM accounts;
SELECT * FROM transactions;

CREATE TABLE fraud_alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id CHAR(36),
    rule_name TEXT,
    alert_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER $$
DROP TRIGGER IF EXISTS trg_velocity_fraud $$
CREATE TRIGGER trg_velocity_fraud
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE v_txn_count INT;
-- 1. Count transactions in last 2 minutes
	SELECT COUNT(*)
    INTO v_txn_count
    FROM transactions
    WHERE account_id = NEW.account_id AND txn_timestamp >= NEW.txn_timestamp - INTERVAL 2 MINUTE;
    
-- 2. If threshold is crossed, then raise fraud alert (Insert in new table called fraud alert)
	IF v_txn_count >= 3 THEN
		INSERT INTO fraud_alerts (account_id,  rule_name, alert_message) VALUES
		(NEW.account_id, 'Velocity_rule', 'High number of transactions in short duration');
	
-- 3. Increase risk score by 20 for each transaction within that window
			UPDATE accounts
			SET risk_score = risk_score + 20
			WHERE account_id = NEW.account_id;
	END IF;
END $$
DELIMITER ;

-- II. Auto freeze based on risk score

-- Create auto freeze trigger if risk_score > 60

DELIMITER $$
DROP TRIGGER IF EXISTS trg_auto_freeze_account $$
CREATE TRIGGER trg_auto_freeze_account
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE v_risk_score INT;
    
-- 1. Fetch current risk score
	SELECT risk_score
    INTO v_risk_score
    FROM accounts
    WHERE account_id = NEW.account_id;
    
-- 2. Freeze account if risk too high
	IF v_risk_score > 60 THEN
		UPDATE accounts
			SET account_status = 'FROZEN'
            WHERE account_id = NEW.account_id;
    END IF;
END $$
delimiter ;

-- III. Create Notification system
-- 1. Create notification table

CREATE TABLE notification_queue(
notification_id INT AUTO_INCREMENT PRIMARY KEY,
account_id CHAR(36),
event_type TEXT,
message TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
processed BOOLEAN DEFAULT FALSE);

-- 2. Whenever velocity attack appears, update Notification table

DELIMITER $$
DROP TRIGGER IF EXISTS trg_notification_vel $$
CREATE TRIGGER trg_notification_vel
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE v_txn_count INT;
	SELECT COUNT(*)
    INTO v_txn_count
    FROM transactions
    WHERE account_id = NEW.account_id AND txn_timestamp >= NEW.txn_timestamp - INTERVAL 2 MINUTE;
    IF
		v_txn_count >= 3 THEN
			INSERT INTO notification_queue(account_id, event_type, message) VALUES
				(NEW.account_id, 'FRAUD velocity detected', 'High Transaction velocity');
    END IF;
END $$
DELIMITER ;

-- 3. Whenever an account gets frozen, update Notification table

DELIMITER $$
DROP TRIGGER IF EXISTS trg_notify_account_freeze $$
CREATE TRIGGER trg_notify_account_freeze
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
	IF OLD.account_status = 'ACTIVE' AND
		NEW.account_status = 'FROZEN' THEN
			INSERT INTO notification_queue(account_id, event_type, message) VALUES
				(NEW.account_id, 'Account frozen', 'Account frozen due to suspicious activity');
	END IF;
END $$
DELIMITER ;