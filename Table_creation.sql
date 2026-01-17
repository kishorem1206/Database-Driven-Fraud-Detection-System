-- =====================================================
-- BANK FRAUD(MySQL):
-- =====================================================
	
-- -----------------------------
-- DELETE EXISTING TABLES IF ANY
-- -----------------------------
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;

-- -----------------------------
-- CUSTOMERS
-- -----------------------------
CREATE TABLE customers (
    customer_id CHAR(36) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customers (customer_id, full_name, email) VALUES
(UUID(),'Rahul Sharma','rahul.sharma@bankdemo.com'),
(UUID(),'Ananya Gupta','ananya.gupta@bankdemo.com'),
(UUID(),'David Wilson','david.wilson@bankdemo.com'),
(UUID(),'Priya Mehta','priya.mehta@bankdemo.com'),
(UUID(),'Rohit Verma','rohit.verma@bankdemo.com'),
(UUID(),'Neha Kapoor','neha.kapoor@bankdemo.com'),
(UUID(),'Amit Singh','amit.singh@bankdemo.com'),
(UUID(),'Sneha Iyer','sneha.iyer@bankdemo.com'),
(UUID(),'Karan Malhotra','karan.malhotra@bankdemo.com'),
(UUID(),'Pooja Nair','pooja.nair@bankdemo.com'),
(UUID(),'Suresh Rao','suresh.rao@bankdemo.com'),
(UUID(),'Meera Joshi','meera.joshi@bankdemo.com'),
(UUID(),'Vikram Patel','vikram.patel@bankdemo.com'),
(UUID(),'Kavita Kulkarni','kavita.kulkarni@bankdemo.com'),
(UUID(),'Arjun Khanna','arjun.khanna@bankdemo.com'),
(UUID(),'Nikhil Bansal','nikhil.bansal@bankdemo.com'),
(UUID(),'Riya Choudhary','riya.choudhary@bankdemo.com'),
(UUID(),'Manish Agarwal','manish.agarwal@bankdemo.com'),
(UUID(),'Shalini Deshpande','shalini.deshpande@bankdemo.com'),
(UUID(),'Siddharth Jain','siddharth.jain@bankdemo.com'),
(UUID(),'Deepak Mishra','deepak.mishra@bankdemo.com'),
(UUID(),'Ayesha Khan','ayesha.khan@bankdemo.com'),
(UUID(),'Tarun Saxena','tarun.saxena@bankdemo.com'),
(UUID(),'Bhavya Arora','bhavya.arora@bankdemo.com'),
(UUID(),'Nitin Srivastava','nitin.srivastava@bankdemo.com');

-- -----------------------------
-- ACCOUNTS
-- -----------------------------
CREATE TABLE accounts (
    account_id CHAR(36) PRIMARY KEY,
    customer_id CHAR(36),
    account_status VARCHAR(20),
    risk_score INT DEFAULT 0,
    daily_txn_limit DECIMAL(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),
    CONSTRAINT chk_account_status
        CHECK (account_status IN ('ACTIVE','FROZEN','RESTRICTED'))
);

SET @row_num := 0;

INSERT INTO accounts (account_id, customer_id, account_status, daily_txn_limit)
SELECT
    UUID(),
    customer_id,
    'ACTIVE',
    CASE
        WHEN (@row_num := @row_num + 1) <= 5 THEN 5000
        WHEN @row_num <= 10 THEN 10000
        WHEN @row_num <= 20 THEN 25000
        ELSE 50000
    END
FROM customers;

-- -----------------------------
-- TRANSACTIONS
-- -----------------------------
CREATE TABLE transactions (
    txn_id CHAR(36) PRIMARY KEY,
    account_id CHAR(36),
    amount DECIMAL(12,2) NOT NULL,
    txn_type VARCHAR(20),
    merchant_country VARCHAR(10),
    device_id VARCHAR(50),
    txn_timestamp TIMESTAMP NOT NULL,
    CONSTRAINT fk_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),
    CONSTRAINT chk_txn_type
        CHECK (txn_type IN ('ATM','POS','ONLINE','TRANSFER'))
);

-- helper table to mimic generate_series(1,4)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 4
)
INSERT INTO transactions (
    txn_id,
    account_id,
    amount,
    txn_type,
    merchant_country,
    device_id,
    txn_timestamp
)
SELECT
    UUID(),
    a.account_id,
    (
        CASE
            WHEN c.full_name LIKE 'Rahul%' THEN 1200
            WHEN c.full_name LIKE 'Ananya%' THEN 800
            WHEN c.full_name LIKE 'David%' THEN 300
            WHEN c.full_name LIKE 'Priya%' THEN 1500
            ELSE 600
        END
        + (seq.n % 3) * 50
    ),
    CASE (seq.n % 4)
        WHEN 0 THEN 'ATM'
        WHEN 1 THEN 'POS'
        WHEN 2 THEN 'ONLINE'
        ELSE 'TRANSFER'
    END,
    'IN',
    CONCAT('device_', LEFT(a.account_id,6)),
    CURRENT_TIMESTAMP - INTERVAL seq.n HOUR
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
JOIN seq;

-- -----------------------------
-- VERIFICATION
-- -----------------------------
SELECT COUNT(*) AS customers FROM customers; =25
SELECT COUNT(*) AS accounts FROM accounts; =25
SELECT COUNT(*) AS transactions FROM transactions; =100
