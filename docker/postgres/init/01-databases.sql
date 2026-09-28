-- Patrón base de datos por servicio: cada microservicio es dueño de su propia base de datos.
CREATE DATABASE users;
CREATE DATABASE plans;
CREATE DATABASE chat;
CREATE DATABASE notifications;
CREATE DATABASE ai;
CREATE DATABASE keycloak;

-- El servicio de planes necesita PostGIS para las consultas geoespaciales.
\connect plans
CREATE EXTENSION IF NOT EXISTS postgis;
