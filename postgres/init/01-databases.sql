-- Bancos do Evolution Go (roda uma única vez, na primeira subida do volume).
-- Equivale ao docker/examples/init-db.sql oficial + reciclagem de idle.

CREATE DATABASE evogo_auth;
CREATE DATABASE evogo_users;

-- Rede de segurança contra conexões órfãs (pool vazado): encerra sessões
-- idle há mais de 5 minutos. A correção definitiva é o patch
-- patches/001-shared-sqlstore-pool.patch; isto aqui só contém o estrago.
ALTER DATABASE evogo_auth  SET idle_session_timeout = '5min';
ALTER DATABASE evogo_users SET idle_session_timeout = '5min';

SELECT 'Bancos evogo_auth e evogo_users criados' AS message;
