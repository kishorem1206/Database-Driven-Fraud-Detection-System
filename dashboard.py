import streamlit as st
import mysql.connector
import pandas as pd
import smtplib
import os
from email.mime.text import MIMEText
from dotenv import load_dotenv
import plotly.express as px

# -------------------------------------------------
# Load env variables
# -------------------------------------------------
load_dotenv()

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

# -------------------------------------------------
# Email sender
# -------------------------------------------------
def send_email(subject, body):
    msg = MIMEText(body, "html")
    msg["From"] = SMTP_USER
    msg["To"] = SMTP_USER
    msg["Subject"] = subject

    with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)

# -------------------------------------------------
# Page config
# -------------------------------------------------
st.set_page_config(
    page_title="Bank Fraud Monitoring",
    page_icon="🚨",
    layout="wide"
)

st.title("🚨 Bank Fraud Monitoring Dashboard")
st.caption("MySQL Trigger–Driven Fraud Detection System")

# -------------------------------------------------
# Database connection
# -------------------------------------------------
@st.cache_resource
def get_connection():
    return mysql.connector.connect(
        host="127.0.0.1",
        database="projects",
        user="root",
        password="Kishore@6",   # 🔴 change if needed
        port=3306,
        use_pure=True
    )

try:
    conn = get_connection()
    st.success("✅ Database connected successfully")
except Exception as e:
    st.error("❌ Database connection failed")
    st.code(str(e))
    st.stop()

def load_df(query):
    return pd.read_sql(query, conn)

# -------------------------------------------------
# KPI SECTION
# -------------------------------------------------
st.subheader("📌 Key Risk Metrics")

kpi_df = load_df("""
    SELECT
        COUNT(*) AS total_accounts,
        SUM(account_status = 'FROZEN') AS frozen_accounts,
        SUM(risk_score >= 60) AS high_risk_accounts
    FROM accounts
""")

k1, k2, k3 = st.columns(3)
k1.metric("🏦 Total Accounts", int(kpi_df.total_accounts[0]))
k2.metric("🚫 Frozen Accounts", int(kpi_df.frozen_accounts[0]))
k3.metric("⚠️ High Risk Accounts (≥60)", int(kpi_df.high_risk_accounts[0]))

st.divider()

# -------------------------------------------------
# ACCOUNTS OVERVIEW
# -------------------------------------------------
st.subheader("🏦 Accounts Overview")

accounts_df = load_df("""
    SELECT
        c.full_name AS customer_name,
        a.account_id,
        a.account_status,
        a.risk_score,
        a.daily_txn_limit
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    ORDER BY a.risk_score DESC
""")

st.dataframe(accounts_df, use_container_width=True)

# -------------------------------------------------
# VISUAL: Risk Distribution
# -------------------------------------------------
st.subheader("📊 Risk Score Distribution")

fig_risk = px.histogram(
    accounts_df,
    x="risk_score",
    color="account_status",
    nbins=20,
    title="Risk Score Distribution by Account Status"
)

st.plotly_chart(fig_risk, use_container_width=True)

# -------------------------------------------------
# VISUAL: Account Status Donut
# -------------------------------------------------
st.subheader("🧩 Account Status Breakdown")

status_df = load_df("""
    SELECT account_status, COUNT(*) AS count
    FROM accounts
    GROUP BY account_status
""")

fig_status = px.pie(
    status_df,
    names="account_status",
    values="count",
    hole=0.5,
    title="Account Status Distribution"
)

st.plotly_chart(fig_status, use_container_width=True)

st.divider()

# -------------------------------------------------
# TABS
# -------------------------------------------------
tab1, tab2 = st.tabs(["🚩 Fraud Alerts", "🔔 Notifications"])

# -------------------- FRAUD ALERTS TAB ----------------------
with tab1:
    st.subheader("🚩 Fraud Alerts")

    alerts_df = load_df("""
        SELECT
            c.full_name AS customer_name,
            a.account_id,
            f.rule_name,
            f.alert_message,
            f.created_at
        FROM fraud_alerts f
        JOIN accounts a ON f.account_id = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
        ORDER BY f.created_at DESC
    """)

    if alerts_df.empty:
        st.info("No fraud alerts yet.")
    else:
        st.dataframe(alerts_df, use_container_width=True)

        alerts_df["created_at"] = pd.to_datetime(alerts_df["created_at"])
        trend_df = (
            alerts_df
            .groupby(alerts_df["created_at"].dt.date)
            .size()
            .reset_index(name="alert_count")
        )

        fig_trend = px.line(
            trend_df,
            x="created_at",
            y="alert_count",
            markers=True,
            title="🚨 Fraud Alerts Trend Over Time"
        )

        st.plotly_chart(fig_trend, use_container_width=True)

# -------------------- NOTIFICATIONS TAB ----------------------
with tab2:
    st.subheader("🔔 Notifications")

    notif_df = load_df("""
        SELECT
            c.full_name AS customer_name,
            a.account_id,
            n.event_type,
            n.message,
            n.created_at
        FROM notification_queue n
        JOIN accounts a ON n.account_id = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
        ORDER BY n.created_at DESC
    """)

    if notif_df.empty:
        st.info("No notifications yet.")
    else:
        st.dataframe(notif_df, use_container_width=True)

    st.markdown("---")
    st.subheader("📧 Email Action")

    if st.button("📧 Send Email for Latest Notification"):
        if notif_df.empty:
            st.warning("No notifications available")
        else:
            latest = notif_df.iloc[0]

            email_body = f"""
            <h3>🚨 Bank Fraud Notification</h3>
            <p><b>Customer:</b> {latest.customer_name}</p>
            <p><b>Account ID:</b> {latest.account_id}</p>
            <p><b>Event:</b> {latest.event_type}</p>
            <p><b>Message:</b> {latest.message}</p>
            <p><b>Time:</b> {latest.created_at}</p>

            <a href="http://localhost:8501"
               style="display:inline-block;padding:10px 16px;
                      background:#ff4b4b;color:white;
                      text-decoration:none;border-radius:6px;">
               🔍 Open Fraud Dashboard
            </a>
            """

            send_email(
                subject=f"[BANK ALERT] {latest.event_type}",
                body=email_body
            )

            st.success("✅ Email sent successfully")

st.divider()

# -------------------------------------------------
# TRANSACTION SIMULATOR
# -------------------------------------------------
st.subheader("🧪 Transaction Simulator")

active_accounts = accounts_df[accounts_df.account_status == "ACTIVE"]

with st.form("txn_form"):
    customer = st.selectbox(
        "Select Customer",
        active_accounts["customer_name"].tolist()
    )

    account_id = active_accounts[
        active_accounts.customer_name == customer
    ]["account_id"].values[0]

    amount = st.number_input("Amount", min_value=1, step=100)
    txn_type = st.selectbox("Transaction Type", ["POS", "ATM", "TRANSFER"])

    submit = st.form_submit_button("Submit Transaction")

    if submit:
        try:
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO transactions
                VALUES (
                    UUID(),
                    %s,
                    %s,
                    %s,
                    'IN',
                    'streamlit_ui',
                    CURRENT_TIMESTAMP
                )
            """, (account_id, amount, txn_type))
            conn.commit()
            st.success(f"Transaction submitted for {customer}")
        except Exception as e:
            st.error("Transaction failed")
            st.code(str(e))
