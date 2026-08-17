-- ============================================================
-- Same-Store Sales (Like-for-Like) Revenue Analysis
-- Compares monthly revenue vs. the same month last year,
-- restricted to stores that were open for at least 13 months.
--
-- Adapted for DuckDB, reading directly from CSVs:
--   lojas.csv, dim_produtos.csv, vendas.csv
-- ============================================================

WITH meses AS (
    SELECT
        strftime(DATE_TRUNC('month', DATE '2023-01-01' + INTERVAL (seq) MONTH), '%Y%m') AS ano_mes_ref
    FROM range(0, DATE_DIFF('month', DATE '2023-01-01', DATE '2025-12-01') + 1) AS t(seq)
    ORDER BY ano_mes_ref
),

lojas AS (
    SELECT
        cod_loja,
        dt_aber,
        dt_enc,
        CAST(dt_aber AS DATE) + INTERVAL 13 MONTH AS data_13_meses,
        strftime(CAST(dt_aber AS DATE) + INTERVAL 13 MONTH, '%Y%m') AS mes_13_meses
    FROM read_csv_auto('lojas.csv')
),

lojas_meses AS (
    SELECT
        meses.ano_mes_ref,
        CAST((CAST(meses.ano_mes_ref AS INT) - 100) AS VARCHAR) AS ref_ly,
        cod_loja,
        dt_aber,
        dt_enc
    FROM lojas
    CROSS JOIN meses
    WHERE lojas.mes_13_meses <= meses.ano_mes_ref
      AND (
            dt_enc = '-'
            OR CASE
                 WHEN dt_enc <> '-' THEN strftime(CAST(dt_enc AS TIMESTAMP), '%Y%m')
                 ELSE '0'
               END > meses.ano_mes_ref
          )
),

atual AS (
    SELECT
        year(CAST(v.data_movimento AS DATE))  AS ano,
        month(CAST(v.data_movimento AS DATE)) AS mes,
        strftime(CAST(v.data_movimento AS DATE), '%Y%m') AS ano_mes,
        SUM(v.cc_venda_bruta) AS receita
    FROM read_csv_auto('vendas.csv') v
    INNER JOIN read_csv_auto('dim_produtos.csv') dp
            ON v.codigo_produto = dp.codigo_produto
    INNER JOIN lojas_meses
            ON strftime(CAST(v.data_movimento AS DATE), '%Y%m') = lojas_meses.ano_mes_ref
           AND CAST(v.codigo_filial AS VARCHAR) = lojas_meses.cod_loja
    GROUP BY 1, 2, 3
),

ly AS (
    SELECT
        lojas_meses.ano_mes_ref,
        SUM(v.cc_venda_bruta) AS receita
    FROM read_csv_auto('vendas.csv') v
    INNER JOIN read_csv_auto('dim_produtos.csv') dp
            ON v.codigo_produto = dp.codigo_produto
    INNER JOIN lojas_meses
            ON strftime(CAST(v.data_movimento AS DATE), '%Y%m') = lojas_meses.ref_ly
           AND CAST(v.codigo_filial AS VARCHAR) = lojas_meses.cod_loja
    GROUP BY 1
)

SELECT
    atual.ano,
    atual.mes,
    atual.ano_mes,
    atual.receita,
    ly.receita AS receita_ly,
    ROUND(100.0 * (atual.receita - ly.receita) / ly.receita, 2) AS crescimento_pct
FROM atual
INNER JOIN ly ON atual.ano_mes = ly.ano_mes_ref
ORDER BY 1, 2;
