-- =============================================================================
-- CASO 1: Estrategia de Seguridad
-- =============================================================================
-- CONECTAR COMO: SYS

-- 1. Creación de Usuarios

ALTER SESSION SET "_Oracle_Script"=TRUE;

-- Usuario Dueño (Owner)
CREATE USER PRY2205_EFT
    IDENTIFIED BY "PRY2205.semana_9"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

-- Usuario Desarrollador (DES)
CREATE USER PRY2205_EFT_DES
    IDENTIFIED BY "PRY2205.semana_9"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS;

-- Usuario Consultor (CON)
CREATE USER PRY2205_EFT_CON
    IDENTIFIED BY "PRY2205.semana_9"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS;

-- Permiso básico de conexión
GRANT CREATE SESSION TO PRY2205_EFT;
GRANT CREATE SESSION TO PRY2205_EFT_DES;
GRANT CREATE SESSION TO PRY2205_EFT_CON;

-- 2. Creación de Roles y Asignación de Privilegios

-- Rol para Desarrollador (PRY2205_ROL_D)
-- Crear vistas, perfiles, usuarios.
CREATE ROLE PRY2205_ROL_D;
GRANT CREATE VIEW, CREATE PROFILE, CREATE USER TO PRY2205_ROL_D;
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;

-- Rol para Consultor (PRY2205_ROL_C)
-- Solo consultar
CREATE ROLE PRY2205_ROL_C;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

-- Privilegios para el Owner (PRY2205_EFT)
-- Tareas: Crear tablas, índices, vistas, secuencias, sinónimos.
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE SYNONYM, CREATE PUBLIC SYNONYM, CREATE PROCEDURE TO PRY2205_EFT;

-- =============================================================================
-- Ejecutar como "PRY2205_EFT"
        SHOW USER;
-- =============================================================================


-- Creación de Sinónimos Públicos
-- Usar sinónimos públicos para ocultar los nombres reales de las tablas base
-- y facilitar el acceso a los otros usuarios

CREATE OR REPLACE PUBLIC SYNONYM SYN_PROFESIONAL FOR PRY2205_EFT.PROFESIONAL;
CREATE OR REPLACE PUBLIC SYNONYM SYN_PROFESION FOR PRY2205_EFT.PROFESION;
CREATE OR REPLACE PUBLIC SYNONYM SYN_ISAPRE FOR PRY2205_EFT.ISAPRE;
CREATE OR REPLACE PUBLIC SYNONYM SYN_TCONTRATO FOR PRY2205_EFT.TIPO_CONTRATO;
CREATE OR REPLACE PUBLIC SYNONYM SYN_RANGOS FOR PRY2205_EFT.RANGOS_SUELDOS;
CREATE OR REPLACE PUBLIC SYNONYM SYN_EMPRESA FOR PRY2205_EFT.EMPRESA;
CREATE OR REPLACE PUBLIC SYNONYM SYN_ASESORIA FOR PRY2205_EFT.ASESORIA;
CREATE OR REPLACE PUBLIC SYNONYM SYN_CARTOLA FOR PRY2205_EFT.CARTOLA_PROFESIONALES;

-- Asignación de Permisos de Acceso a los Roles
-- El Desarrollador necesita leer las tablas para crear el informe e insertar en CARTOLA.

GRANT SELECT ON PROFESIONAL TO PRY2205_ROL_D;
GRANT SELECT ON PROFESION TO PRY2205_ROL_D;
GRANT SELECT ON ISAPRE TO PRY2205_ROL_D;
GRANT SELECT ON TIPO_CONTRATO TO PRY2205_ROL_D;
GRANT SELECT ON RANGOS_SUELDOS TO PRY2205_ROL_D;
GRANT SELECT ON EMPRESA TO PRY2205_ROL_D;
GRANT SELECT ON ASESORIA TO PRY2205_ROL_D;

-- Permisos específicos sobre la tabla de reporte (lectura y escritura para el informe)
GRANT SELECT, INSERT, UPDATE, DELETE ON CARTOLA_PROFESIONALES TO PRY2205_EFT_DES WITH GRANT OPTION;
-- with grant option para que luego el desarrollador pueda darle grant al consultor


-- =============================================================================
-- CASO 2: Creacion de Informe
-- =============================================================================
-- Conectar como PRY2205_EFT_DES
SHOW USER;


INSERT INTO SYN_CARTOLA (
    RUT_PROFESIONAL,
    NOMBRE_PROFESIONAL,
    PROFESION,
    ISAPRE,
    SUELDO_BASE,
    PORC_COMISION_PROFESIONAL,
    VALOR_TOTAL_COMISION,
    PORCENTATE_HONORARIO,
    BONO_MOVILIZACION,
    TOTAL_PAGAR
)
SELECT
    P.RUTPROF,
    INITCAP(P.NOMPRO || ' ' || P.APPPRO || ' ' || P.APMPRO) AS NOMBRE_COMPLETO,
    PR.NOMPROFESION,
    I.NOMISAPRE,
    P.SUELDO,
    -- Porcentaje Comision: Si es nulo, es 0
    NVL(P.COMISION, 0),
    -- Valor Total Comision: Sueldo * %Comision
    ROUND(P.SUELDO * NVL(P.COMISION, 0), 0),
    -- Valor Honorario: Calculado según rango de sueldo en tabla RANGOS_SUELDOS
    -- Usamos subconsulta escalar para obtener el porcentaje exacto y multiplicarlo
    ROUND(P.SUELDO * (
            SELECT R.HONOR_PCT/100
            FROM SYN_RANGOS R
            WHERE P.SUELDO BETWEEN R.S_MIN AND R.S_MAX
          ), 0) AS VALOR_HONORARIO,
    -- Bono Movilización: Fijo según nombre de contrato
    CASE TC.NOMTCONTRATO
        WHEN 'Indefinido Jornada Completa' THEN 150000
        WHEN 'Indefinido Jornada Parcial'  THEN 120000
        WHEN 'Plazo fijo'                  THEN 60000
        WHEN 'Honorarios'                  THEN 50000
        ELSE 0
    END AS BONO_MOVILIZACION,
    -- Total a Pagar: Suma de todo lo anterior
    ROUND(
        P.SUELDO +
        (P.SUELDO * NVL(P.COMISION, 0)) +
        (P.SUELDO * (SELECT R.HONOR_PCT/100 FROM SYN_RANGOS R WHERE P.SUELDO BETWEEN R.S_MIN AND R.S_MAX)) +
        CASE TC.NOMTCONTRATO
            WHEN 'Indefinido Jornada Completa' THEN 150000
            WHEN 'Indefinido Jornada Parcial'  THEN 120000
            WHEN 'Plazo fijo'                  THEN 60000
            WHEN 'Honorarios'                  THEN 50000
            ELSE 0
        END
    , 0) AS TOTAL_PAGAR
FROM
    SYN_PROFESIONAL P
    JOIN SYN_PROFESION PR ON P.IDPROFESION = PR.IDPROFESION
    JOIN SYN_ISAPRE I ON P.IDISAPRE = I.IDISAPRE
    JOIN SYN_TCONTRATO TC ON P.IDTCONTRATO = TC.IDTCONTRATO
ORDER BY
    PR.NOMPROFESION,
    P.SUELDO DESC,
    P.COMISION,
    P.RUTPROF;

COMMIT;

GRANT SELECT ON SYN_CARTOLA TO PRY2205_EFT_CON;

-- =============================================================================
-- CASO 3: OPTIMIZACIÓN (VISTA E ÍNDICES)
-- =============================================================================
-- Conectar como PRY2205_EFT
    SHOW USER;

-- CASO 3.1: CREACIÓN DE VISTA VW_EMPRESAS_ASESORADAS

CREATE OR REPLACE VIEW VW_EMPRESAS_ASESORADAS AS
SELECT
    E.RUT_EMPRESA,
    E.NOMEMPRESA AS NOMBRE_EMPRESA,
    E.IVA_DECLARADO AS IVA,
    -- Antigüedad: Año actual - Año inicio actividades
    EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM E.FECHA_INICIACION_ACTIVIDADES) AS ANIOS_EXISTENCIA,
    -- Total Asesorias Anuales Promedio: Total / 12
    ROUND(COUNT(A.RUTPROF) / 12) AS TOTAL_ASESORIAS_ANUALES,
    -- Devolucion IVA: IVA * (Promedio / 100)
    ROUND(E.IVA_DECLARADO * (ROUND(COUNT(A.RUTPROF) / 12) / 100)) AS DEVOLUCION_IVA,
    -- Tipo Cliente (Logica anidada según promedio)
    CASE
        WHEN ROUND(COUNT(A.RUTPROF) / 12) > 5 THEN 'CLIENTE PREMIUM'
        WHEN ROUND(COUNT(A.RUTPROF) / 12) BETWEEN 3 AND 5 THEN 'CLIENTE'
        ELSE 'CLIENTE POCO CONCURRIDO'
    END AS TIPO_CLIENTE,
    -- Promoción / Corresponde
    CASE
        WHEN ROUND(COUNT(A.RUTPROF) / 12) > 5 THEN -- PREMIUM
            CASE WHEN ROUND(COUNT(A.RUTPROF) / 12) >= 7 THEN '1 ASESORIA GRATIS'
                 ELSE '1 ASESORIA 40% DE DESCUENTO' END
        WHEN ROUND(COUNT(A.RUTPROF) / 12) BETWEEN 3 AND 5 THEN -- CLIENTE
            CASE WHEN ROUND(COUNT(A.RUTPROF) / 12) = 5 THEN '1 ASESORIA 30% DE DESCUENTO'
                 ELSE '1 ASESORIA 20% DE DESCUENTO' END
        ELSE 'CAPTAR CLIENTE' -- POCO CONCURRIDO
    END AS CORRESPONDE
FROM
    EMPRESA E
    JOIN ASESORIA A ON E.IDEMPRESA = A.IDEMPRESA
WHERE
    -- Filtro: Asesorias terminadas el año ANTERIOR al actual
    EXTRACT(YEAR FROM A.FIN) = EXTRACT(YEAR FROM SYSDATE) - 1
GROUP BY
    E.RUT_EMPRESA, E.NOMEMPRESA, E.IVA_DECLARADO, E.FECHA_INICIACION_ACTIVIDADES
ORDER BY
    E.NOMEMPRESA ASC;

-- Permiso para que Consultor vea la vista
GRANT SELECT ON VW_EMPRESAS_ASESORADAS TO PRY2205_ROL_C;


-- CASO 3.2: CREACIÓN DE ÍNDICES
-- Optimizar la vista anterior.

-- Índice basado en función para optimizar filtro del año
CREATE INDEX IDX_ASESORIA_ANIO_FIN ON ASESORIA(EXTRACT(YEAR FROM FIN));

-- Índice para optimizar el cruce join
CREATE INDEX IDX_ASESORIA_IDEMPRESA ON ASESORIA(IDEMPRESA);
