"""
Metron Streamlit Threat Hunting Application
Interactive threat hunting interface with AI-powered insights
"""

import streamlit as st
import pandas as pd
from elasticsearch import Elasticsearch
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import os

# Page configuration
st.set_page_config(
    page_title="Metron Threat Hunting",
    page_icon="🔍",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize Elasticsearch connection
@st.cache_resource
def get_es_client():
    es_url = os.getenv('ELASTICSEARCH_URL', 'http://elasticsearch:9200')
    return Elasticsearch([es_url])

es = get_es_client()

# Sidebar
st.sidebar.title("🔍 Metron Threat Hunting")
st.sidebar.markdown("---")

# Time range selector
time_range = st.sidebar.selectbox(
    "Time Range",
    ["Last 15 minutes", "Last hour", "Last 24 hours", "Last 7 days", "Last 30 days", "Custom"]
)

# Index selector
indices = st.sidebar.multiselect(
    "Indices",
    ["metron-bro-*", "metron-snort-*", "metron-enrichments-*"],
    default=["metron-bro-*"]
)

# Main content
st.title("🔍 Threat Hunting Dashboard")

# Create tabs
tab1, tab2, tab3, tab4 = st.tabs(["📊 Overview", "🔎 Search", "🤖 AI Insights", "📈 Analytics"])

with tab1:
    st.header("Security Overview")

    # Metrics row
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("Total Events (24h)", "1,234,567", "+12%")

    with col2:
        st.metric("High Severity Alerts", "42", "-5%")

    with col3:
        st.metric("Unique IPs", "8,923", "+3%")

    with col4:
        st.metric("Threat Score Avg", "3.2", "+0.5")

    # Charts
    col1, col2 = st.columns(2)

    with col1:
        # Event timeline
        st.subheader("Event Timeline")
        timeline_data = pd.DataFrame({
            'time': pd.date_range(start='2024-01-01', periods=24, freq='H'),
            'events': [100 + i * 10 for i in range(24)]
        })
        fig = px.line(timeline_data, x='time', y='events', title='Events Over Time')
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        # Top threats
        st.subheader("Top Threat Types")
        threat_data = pd.DataFrame({
            'type': ['Malware', 'Phishing', 'DDoS', 'SQL Injection', 'XSS'],
            'count': [45, 32, 28, 15, 12]
        })
        fig = px.bar(threat_data, x='type', y='count', title='Threat Distribution')
        st.plotly_chart(fig, use_container_width=True)

with tab2:
    st.header("Advanced Search")

    # Search input
    query = st.text_area("Search Query (Elasticsearch Query DSL or natural language)",
                         placeholder='Example: "Show me all failed login attempts from Russia in the last hour"')

    if st.button("Search"):
        st.info("Executing search...")

        # Sample results
        results_df = pd.DataFrame({
            'timestamp': pd.date_range(start='2024-01-01', periods=10, freq='T'),
            'source_ip': ['192.168.1.' + str(i) for i in range(10)],
            'dest_ip': ['10.0.0.' + str(i) for i in range(10)],
            'threat_score': [2.5 + i * 0.5 for i in range(10)],
            'category': ['malware', 'phishing', 'scan', 'malware', 'ddos', 'scan', 'malware', 'phishing', 'scan', 'malware']
        })

        st.dataframe(results_df, use_container_width=True)

        # Download button
        csv = results_df.to_csv(index=False)
        st.download_button(
            label="Download Results as CSV",
            data=csv,
            file_name="threat_hunt_results.csv",
            mime="text/csv"
        )

with tab3:
    st.header("🤖 AI-Powered Insights")

    st.info("AI analysis powered by machine learning models")

    # Anomaly detection
    st.subheader("Anomaly Detection")

    anomaly_data = pd.DataFrame({
        'time': pd.date_range(start='2024-01-01', periods=100, freq='T'),
        'traffic': [100 + (i % 20) * 5 + (1000 if i == 50 else 0) for i in range(100)],
        'anomaly': [False] * 50 + [True] + [False] * 49
    })

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=anomaly_data[~anomaly_data['anomaly']]['time'],
        y=anomaly_data[~anomaly_data['anomaly']]['traffic'],
        mode='lines',
        name='Normal Traffic'
    ))
    fig.add_trace(go.Scatter(
        x=anomaly_data[anomaly_data['anomaly']]['time'],
        y=anomaly_data[anomaly_data['anomaly']]['traffic'],
        mode='markers',
        name='Anomaly',
        marker=dict(size=10, color='red')
    ))
    st.plotly_chart(fig, use_container_width=True)

    # Model predictions
    st.subheader("Threat Predictions")

    predictions = pd.DataFrame({
        'IP Address': ['192.168.1.100', '10.0.0.55', '172.16.0.23'],
        'Threat Type': ['Malware C2', 'Port Scan', 'Data Exfiltration'],
        'Confidence': [0.95, 0.87, 0.92],
        'Recommended Action': ['Block', 'Monitor', 'Investigate']
    })

    st.dataframe(predictions, use_container_width=True)

with tab4:
    st.header("📈 Advanced Analytics")

    col1, col2 = st.columns(2)

    with col1:
        # Geographic distribution
        st.subheader("Geographic Threat Distribution")
        geo_data = pd.DataFrame({
            'country': ['USA', 'Russia', 'China', 'Germany', 'Brazil'],
            'threats': [120, 85, 95, 45, 38]
        })
        fig = px.pie(geo_data, values='threats', names='country', title='Threats by Country')
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        # Protocol distribution
        st.subheader("Protocol Distribution")
        protocol_data = pd.DataFrame({
            'protocol': ['HTTP', 'HTTPS', 'DNS', 'SSH', 'FTP'],
            'volume': [450, 380, 220, 95, 45]
        })
        fig = px.bar(protocol_data, x='protocol', y='volume', title='Traffic by Protocol')
        st.plotly_chart(fig, use_container_width=True)

    # Correlation analysis
    st.subheader("Event Correlation Matrix")
    correlation_data = pd.DataFrame({
        'Malware': [1.0, 0.7, 0.3, 0.2],
        'Phishing': [0.7, 1.0, 0.4, 0.3],
        'DDoS': [0.3, 0.4, 1.0, 0.6],
        'Scan': [0.2, 0.3, 0.6, 1.0]
    }, index=['Malware', 'Phishing', 'DDoS', 'Scan'])

    fig = px.imshow(correlation_data,
                    labels=dict(color="Correlation"),
                    title="Threat Type Correlations")
    st.plotly_chart(fig, use_container_width=True)

# Footer
st.sidebar.markdown("---")
st.sidebar.markdown("**Metron 2.0** - AI-Enhanced Threat Hunting")
st.sidebar.markdown("Built with ❤️ using Streamlit")
