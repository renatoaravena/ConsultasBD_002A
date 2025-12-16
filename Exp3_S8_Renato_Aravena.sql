--CASO 1

-- Ejecutar como SYS
-- Crear Usuario Dueño de las tablas (USER1)
ALTER SESSION SET "_Oracle_Script"=TRUE;

CREATE USER PRY2205_USER1
    IDENTIFIED BY "PRY2205.semana_8"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- Dar permiso para conectarse y crear las tablas del script
GRANT CONNECT, RESOURCE TO PRY2205_USER1;

-- Crear Usuario Generico (USER2) - Lo usaremos en el Caso 2
CREATE USER PRY2205_USER2
    IDENTIFIED BY "PRY2205.semana_8"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CONNECT TO PRY2205_USER2; -- Solo conectar por ahora

-- Ejecutar como SYS

-- 1. Crear los Roles
CREATE ROLE PRY2205_ROL_D; -- Para el Dueño (USER1)
CREATE ROLE PRY2205_ROL_P; -- Para el Programador/Analista (USER2)

-- 2. Asignar privilegios al ROL_D (USER1)
-- Según Tabla 2: Crear tablas, índices, vistas, sinónimos
GRANT CREATE TABLE, CREATE VIEW, CREATE ANY INDEX, CREATE SYNONYM, CREATE PUBLIC SYNONYM TO PRY2205_ROL_D;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_USER1; -- Por algun motivo no lo toma si no se lo doy directamente al user, aunque el
                                              -- rol lo tenga asignado

-- 3. Asignar privilegios al ROL_P (USER2)
-- Según Tabla 2: Crear secuencias, disparadores(triggers), tablas
GRANT CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER TO PRY2205_ROL_P;

-- 4. Asignar los roles a los usuarios
GRANT PRY2205_ROL_D TO PRY2205_USER1;
GRANT PRY2205_ROL_P TO PRY2205_USER2;



-- Ejecutar como PRY2205_USER1
-- Dar permiso de lectura sobre las tablas necesarias al ROL del Usuario 2
GRANT SELECT ON PRESTAMO TO PRY2205_ROL_P;
GRANT SELECT ON EJEMPLAR TO PRY2205_ROL_P;
GRANT SELECT ON LIBRO TO PRY2205_ROL_P;
GRANT SELECT ON EMPLEADO TO PRY2205_ROL_P;
GRANT SELECT ON REBAJA_MULTA TO PRY2205_ROL_P;
GRANT SELECT ON CARRERA TO PRY2205_ROL_P;
GRANT SELECT ON ALUMNO TO PRY2205_ROL_P;

-- Crear Sinónimos Públicos (para simplificar el acceso)
CREATE OR REPLACE PUBLIC SYNONYM SYN_PRESTAMO FOR PRY2205_USER1.PRESTAMO;
CREATE OR REPLACE PUBLIC SYNONYM SYN_EJEMPLAR FOR PRY2205_USER1.EJEMPLAR;
CREATE OR REPLACE PUBLIC SYNONYM SYN_LIBRO FOR PRY2205_USER1.LIBRO;
CREATE OR REPLACE PUBLIC SYNONYM SYN_EMPLEADO FOR PRY2205_USER1.EMPLEADO;



---------------------------------------------------------------------------------------

--Caso 2
-- Analizar prestamos de hace 2 años gestionados por empleados(190, 180, 150) y ver stock de libros(S,N)

-- Ejecutar como PRY2205_USER2
-- Secuencia solicitada
CREATE SEQUENCE SEQ_CONTROL_STOCK
    START WITH 1
    INCREMENT BY 1;

-- Tabla con el informe

CREATE TABLE CONTROL_STOCK_LIBROS AS
SELECT
    SEQ_CONTROL_STOCK.NEXTVAL AS ID_CONTROL,
    TEMP.*,
    CASE
        WHEN TEMP.DISPONIBLES > 2 THEN 'S'
        ELSE 'N'
        END AS STOCK_CRITICO

FROM (
         SELECT
             L.LIBROID AS ID_LIBRO,
             L.NOMBRE_LIBRO,

             -- 1. Total Ejemplares
             (SELECT COUNT(*) FROM SYN_EJEMPLAR E WHERE E.LIBROID = L.LIBROID) AS TOTAL_EJEMPLARES,

             -- 2. En Préstamo
             (SELECT COUNT(*)
              FROM SYN_PRESTAMO P
              WHERE P.LIBROID = L.LIBROID
                -- Usamos el AÑO en lugar del día exacto debido que si usamos el dia exacto no calza nada
                AND EXTRACT(YEAR FROM P.FECHA_INICIO) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -24))
             ) AS EN_PRESTAMO,

             -- 3. Disponibles
             (SELECT COUNT(*) FROM SYN_EJEMPLAR E WHERE E.LIBROID = L.LIBROID) -
             (SELECT COUNT(*)
              FROM SYN_PRESTAMO P
              WHERE P.LIBROID = L.LIBROID
                AND EXTRACT(YEAR FROM P.FECHA_INICIO) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -24))
             ) AS DISPONIBLES,

             -- 4. Porcentaje
             ROUND(
                     (SELECT COUNT(*)
                      FROM SYN_PRESTAMO P
                      WHERE P.LIBROID = L.LIBROID
                        AND EXTRACT(YEAR FROM P.FECHA_INICIO) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -24))) /
                     NULLIF((SELECT COUNT(*) FROM SYN_EJEMPLAR E WHERE E.LIBROID = L.LIBROID), 0) * 100
                 , 2) || '%' AS PORCENTAJE_PRESTAMO

         FROM SYN_LIBRO L
         WHERE L.LIBROID IN (
             SELECT DISTINCT P.LIBROID
             FROM SYN_PRESTAMO P
             WHERE EXTRACT(YEAR FROM P.FECHA_INICIO) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -24))
               AND P.EMPLEADOID IN (150, 180, 190)
         )
         ORDER BY L.LIBROID
     ) TEMP;


------------------------------------------------------------

--Caso 3.1 Crear Vista

-- Ejecutar como PRY2205_USER1
DROP VIEW VW_DETALLE_MULTAS;

CREATE OR REPLACE VIEW VW_DETALLE_MULTAS AS
SELECT
    P.PRESTAMOID AS ID_PRESTAMO,
    A.NOMBRE || ' ' || A.APATERNO AS NOMBRE_ALUMNO,
    C.DESCRIPCION AS CARRERA,
    L.LIBROID AS ID_LIBRO,
    TO_CHAR(L.PRECIO, 'L999G999G999') AS PRECIO_LIBRO,
    TO_CHAR(P.FECHA_TERMINO, 'DD/MM/YYYY') AS FECHA_TERMINO,
    TO_CHAR(P.FECHA_ENTREGA, 'DD/MM/YYYY') AS FECHA_ENTREGA,
    (P.FECHA_ENTREGA - P.FECHA_TERMINO) AS DIAS_ATRASO,

    -- Calculo Multa Base: Precio * 0.03 * Dias Atraso
    TO_CHAR(ROUND(L.PRECIO * 0.03 * (P.FECHA_ENTREGA - P.FECHA_TERMINO)), 'L999G999G999') AS VALOR_MULTA,

    -- Porcentaje Rebaja (NVL pone un 0 si no hay convenio)
    NVL(RM.PORC_REBAJA_MULTA, 0) || '%' AS PORC_REBAJA,

    -- Valor Final: Multa - (Multa * Porcentaje/100)
    TO_CHAR(ROUND(
                    (L.PRECIO * 0.03 * (P.FECHA_ENTREGA - P.FECHA_TERMINO)) -
                    ((L.PRECIO * 0.03 * (P.FECHA_ENTREGA - P.FECHA_TERMINO)) * NVL(RM.PORC_REBAJA_MULTA, 0) / 100)
            ), 'L999G999G999') AS VALOR_FINAL

FROM PRESTAMO P
         JOIN ALUMNO A ON P.ALUMNOID = A.ALUMNOID
         JOIN CARRERA C ON A.CARRERAID = C.CARRERAID
         JOIN LIBRO L ON P.LIBROID = L.LIBROID
         LEFT JOIN REBAJA_MULTA RM ON C.CARRERAID = RM.CARRERAID
    -- Left join porque no todas tendran rebaja

WHERE
  -- Filtro de año (hace 2 años)
    EXTRACT(YEAR FROM P.FECHA_TERMINO) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -24))
  -- Solo atrasados
  AND P.FECHA_ENTREGA > P.FECHA_TERMINO
ORDER BY P.FECHA_ENTREGA DESC;

---------------------------------------------------------------------------------------

--Caso 3.2

-- Ejecutar como PRY2205_USER1

-- 1. Índice para el filtro de fechas (Esto acelera el WHERE)
CREATE INDEX IDX_PRESTAMO_FECHAS ON PRESTAMO(FECHA_TERMINO, FECHA_ENTREGA);

-- 2. Índices para los Joins
CREATE INDEX IDX_PRESTAMO_ALUMNO ON PRESTAMO(ALUMNOID);
CREATE INDEX IDX_PRESTAMO_LIBRO ON PRESTAMO(LIBROID);
CREATE INDEX IDX_ALUMNO_CARRERA ON ALUMNO(CARRERAID);