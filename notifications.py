import mysql.connector
import time

# -----------------------------------------
# MySQL connection
# -----------------------------------------

conn = mysql.connector.connect(
    host="localhost",
    database="projects",
    user="root",
    password="password"
)

conn.autocommit = True
cursor = conn.cursor()

# -----------------------------------------
# Mock email sender
# -----------------------------------------
def send_email(account_id, message):
    print(f"[EMAIL SENT] Account: {account_id} | Message: {message}")

# -----------------------------------------
# Notification worker loop
# -----------------------------------------
while True:
    cursor.execute("""
        SELECT notification_id, account_id, message
        FROM notification_queue
        WHERE processed = 0
        ORDER BY created_at
    """)

    rows = cursor.fetchall()

    for notification_id, account_id, message in rows:
        send_email(account_id, message)

        cursor.execute("""
            UPDATE notification_queue
            SET processed = 1
            WHERE notification_id = %s
        """, (notification_id,))

    time.sleep(5)