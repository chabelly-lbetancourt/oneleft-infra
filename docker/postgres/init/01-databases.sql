-- Database per service pattern: each microservice owns its database.
CREATE DATABASE users;
CREATE DATABASE plans;
CREATE DATABASE chat;
CREATE DATABASE notifications;
CREATE DATABASE ai;
CREATE DATABASE keycloak;

-- The plans service needs PostGIS for geospatial queries.
\connect plans
CREATE EXTENSION IF NOT EXISTS postgis;
