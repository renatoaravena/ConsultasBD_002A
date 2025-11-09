-- Caso 1: Listado de Clientes con Rango de Renta
-- Tabla CLIENTE

--Por ello se requiere desarrollar un informe comercial cuyo fin es:
-- 1. Mostrar solo los clientes listados entre un rango de renta definido por el operario que
-- interactúe con el informe, es decir, el desarrollo debe ser capaz de pedir el monto
-- mínimo y máximo de renta a filtrar por pantalla.

-- 2. El reporte debe mostrar el RUT de los clientes con puntos y guion, y considerar solo a
-- los clientes que tienen registrado un número de celular.

-- 3. El objetivo del informe es medir por tramos la rentabilidad de cada uno de los clientes,
-- considerando la siguiente escala:
--       Renta mayor de 500.000 clasifica como 'TRAMO 1'.
--       Renta entre 400.000 y 500.000 clasifica como 'TRAMO 2'.
--       Renta entre 200.000 y 399.999 clasifica como 'TRAMO 3'.
--       Renta menor de 200.000 clasifica como 'TRAMO 4'.

SELECT TO_CHAR(NUMRUT_CLI, '99G999G999') || '-' || TO_CHAR(DVRUT_CLI)      AS "RUT Cliente",
       INITCAP(NOMBRE_CLI || ' ' || APPATERNO_CLI || ' ' || APMATERNO_CLI) AS "Nombre Completo Cliente",
       INITCAP(DIRECCION_CLI)                                              AS "Dirección Cliente",
       TO_CHAR(RENTA_CLI, 'L999G999G999')                                  AS "Renta Cliente",
       SUBSTR(LPAD(CELULAR_CLI, 9, '0'), 1, 2) || '-' ||
       SUBSTR(LPAD(CELULAR_CLI, 9, '0'), 3, 3) || '-' ||
       SUBSTR(LPAD(CELULAR_CLI, 9, '0'), 6, 4)                             AS "Celular Cliente",
       CASE
           WHEN RENTA_CLI > 500000 THEN 'TRAMO 1'
           WHEN RENTA_CLI BETWEEN 400000 AND 500000 THEN 'TRAMO 2'
           WHEN RENTA_CLI BETWEEN 200000 AND 399999 THEN 'TRAMO 3'
           ELSE 'TRAMO 4'
           END                                                             AS "Tramo Renta Cliente"
FROM CLIENTE
WHERE RENTA_CLI BETWEEN :MIN_RENTA AND :MAX_RENTA
  AND CELULAR_CLI IS NOT NULL
ORDER BY "Nombre Completo Cliente";

--Caso 2: Sueldo Promedio por Categoría de Empleados
--tabla EMPLEADO

/* LISTO 1. Las categorías se clasifican por el siguiente código:
        o 1 corresponde Gerente
        o 2 corresponde Supervisor
        o 3 corresponde Ejecutivo de Arriendo
        o 4 corresponde Auxiliar
Listo2. Al igual que el código de sucursal:
        o 10 corresponde Sucursal Las Condes
        o 20 corresponde Sucursal Santiago Centro
        o 30 corresponde Sucursal Providencia
        o 40 corresponde Sucursal Vitacura
3. Listo. De la cantidad de empleados por sucursal se debe calcular el promedio de sueldo y
formatear con signo pesos separando miles.
4. Listo. Este reporte será utilizado por la gerencia para evaluar el impacto de la política de
incentivos y considerar posibles ajustes en la estrategia de compensaciones, para ello
el usuario podrá ingresar por pantalla el valor del sueldo promedio mínimo a
considerar en el reporte.*/

SELECT
    ID_CATEGORIA_EMP AS CODIGO_CATEGORIA,
    CASE
        WHEN ID_CATEGORIA_EMP = 1 THEN 'Gerente'
        WHEN ID_CATEGORIA_EMP = 2 THEN 'Supervisor'
        WHEN ID_CATEGORIA_EMP = 3 THEN 'Ejecutivo de Arriendo'
        WHEN ID_CATEGORIA_EMP = 4 THEN 'Auxiliar'
        ELSE 'Otra Categoría'
    END AS DESCRIPCION_CATEGORIA,
    COUNT(ID_SUCURSAL) AS CANTIDAD_EMPLEADOS,
    CASE
        WHEN ID_SUCURSAL = 10 THEN 'Sucursal Las Condes'
        WHEN ID_SUCURSAL = 20 THEN 'Sucursal Santiago Centro'
        WHEN ID_SUCURSAL = 30 THEN 'Sucursal Providencia'
        WHEN ID_SUCURSAL = 40 THEN 'Sucursal Vitacura'
        ELSE 'Otra Sucursal'
    END AS SUCURSAL,
    TO_CHAR(AVG(SUELDO_EMP), 'L999G999G999') AS SUELDO_PROMEDIO
FROM EMPLEADO
GROUP BY ID_CATEGORIA_EMP, ID_SUCURSAL
HAVING AVG(SUELDO_EMP) >= :SUELDO_PROMEDIO_MINIMO
ORDER BY AVG(SUELDO_EMP) DESC;

/*
Caso 3: Arriendo Promedio por Tipo de Propiedad
TABLA PROPIEDAD

1. Deberá calcular indicadores clave, tales como el total de propiedades registradas, el
promedio del valor de arriendo, de superficie y la razón de arriendo por metro cuadrado.

2. Además, se espera que se transforme el código del tipo de propiedad en una descripción
legible:
    A CASA
    B DEPARTAMENTO
    C LOCAL
    D PARCELA SIN CASA
    E PARCELA CON CASA

3. El reporte final deberá incluir, además de los indicadores anteriores, una clasificación de
las propiedades basada en el valor de arriendo por metro cuadrado, asignando
categorías como menor de 5.000 m² es "Económico", entre 5.000 y 10.000 m² "Medio" o
superior a todos los anteriores "Alto", según los umbrales establecidos.

4. Cabe destacar que el reporte solo mostrará los registros cuyo promedio del valor de
arriendo por m2 sea superior a 1.000

*/

SELECT
    ID_TIPO_PROPIEDAD AS CODIGO_TIPO,
    CASE
        WHEN ID_TIPO_PROPIEDAD = 'A' THEN 'CASA'
        WHEN ID_TIPO_PROPIEDAD = 'B' THEN 'DEPARTAMENTO'
        WHEN ID_TIPO_PROPIEDAD = 'C' THEN 'LOCAL'
        WHEN ID_TIPO_PROPIEDAD = 'D' THEN 'PARCELA SIN CASA'
        WHEN ID_TIPO_PROPIEDAD = 'E' THEN 'PARCELA CON CASA'
        ELSE 'OTRO TIPO'
    END AS DESCRIPCION_TIPO,
    COUNT(ID_TIPO_PROPIEDAD) AS TOTAL_PROPIEDADES,
    TO_CHAR(AVG(VALOR_ARRIENDO), 'L999G999G999') AS PROMEDIO_VALOR_ARRIENDO,
    TO_CHAR(ROUND(AVG(SUPERFICIE),2) , '999G999G999D00') AS PROMEDIO_SUPERFICIE,
    TO_CHAR(AVG(VALOR_ARRIENDO / SUPERFICIE), 'L999G999G999') AS VALOR_ARRIENDO_M2,
    CASE
        WHEN AVG(VALOR_ARRIENDO / SUPERFICIE) < 5000 THEN 'Económico'
        WHEN AVG(VALOR_ARRIENDO / SUPERFICIE) BETWEEN 5000 AND 10000 THEN 'Medio'
        ELSE 'Alto'
    END AS CLASIFICACION
FROM PROPIEDAD
GROUP BY ID_TIPO_PROPIEDAD
HAVING AVG(VALOR_ARRIENDO / SUPERFICIE) > 1000
ORDER BY AVG(VALOR_ARRIENDO / SUPERFICIE) DESC;
