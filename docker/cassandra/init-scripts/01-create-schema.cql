-- Metron Cassandra Schema Initialization
-- Creates keyspace and tables for threat intelligence, enrichment, and profiling

-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS metron
  WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
  };

USE metron;

-- Threat Intelligence Table
CREATE TABLE IF NOT EXISTS threat_intel (
  indicator_type text,
  indicator_value text,
  timestamp timestamp,
  threat_score int,
  source text,
  metadata map<text, text>,
  PRIMARY KEY ((indicator_type, indicator_value), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND compaction = {'class': 'LeveledCompactionStrategy'}
  AND gc_grace_seconds = 86400
  AND comment = 'Threat intelligence indicators';

-- Enrichment Data Table
CREATE TABLE IF NOT EXISTS enrichment_data (
  enrichment_type text,
  indicator text,
  timestamp timestamp,
  data map<text, text>,
  PRIMARY KEY ((enrichment_type, indicator), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND comment = 'Enrichment data for events';

-- Profiler Data Table
CREATE TABLE IF NOT EXISTS profiler_data (
  profile text,
  entity text,
  period text,
  timestamp timestamp,
  measurements map<text, double>,
  PRIMARY KEY ((profile, entity, period), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 2592000
  AND comment = 'Behavioral profiling data (30 day TTL)';

-- GeoIP Enrichment Table
CREATE TABLE IF NOT EXISTS geoip_enrichment (
  ip_address text,
  country text,
  city text,
  latitude double,
  longitude double,
  organization text,
  last_updated timestamp,
  PRIMARY KEY (ip_address)
) WITH comment = 'GeoIP enrichment data';

-- DNS Enrichment Table
CREATE TABLE IF NOT EXISTS dns_enrichment (
  domain text,
  ip_addresses list<text>,
  first_seen timestamp,
  last_seen timestamp,
  metadata map<text, text>,
  PRIMARY KEY (domain)
) WITH comment = 'DNS resolution data';

-- WHOIS Enrichment Table
CREATE TABLE IF NOT EXISTS whois_enrichment (
  domain text,
  registrar text,
  registration_date timestamp,
  expiration_date timestamp,
  nameservers list<text>,
  metadata map<text, text>,
  PRIMARY KEY (domain)
) WITH comment = 'WHOIS enrichment data';

-- Incident Response Table
CREATE TABLE IF NOT EXISTS incidents (
  incident_id uuid,
  created_at timestamp,
  updated_at timestamp,
  severity text,
  status text,
  assignee text,
  alerts list<text>,
  notes text,
  metadata map<text, text>,
  PRIMARY KEY (incident_id)
) WITH comment = 'Security incidents';

-- Insert sample threat intel data
INSERT INTO threat_intel (indicator_type, indicator_value, timestamp, threat_score, source, metadata)
VALUES ('ip', '192.0.2.1', toTimestamp(now()), 85, 'sample', {'description': 'Sample malicious IP'});

INSERT INTO threat_intel (indicator_type, indicator_value, timestamp, threat_score, source, metadata)
VALUES ('domain', 'malicious.example.com', toTimestamp(now()), 90, 'sample', {'description': 'Sample C2 domain'});

INSERT INTO threat_intel (indicator_type, indicator_value, timestamp, threat_score, source, metadata)
VALUES ('hash', 'a1b2c3d4e5f6', toTimestamp(now()), 95, 'sample', {'description': 'Sample malware hash'});
