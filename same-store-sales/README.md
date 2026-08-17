# Same-Store Sales

## Contexto de negócio

Havia uma necessidade recorrente de negócio: todo mês, o time precisava apresentar um material gerencial para a alta gestão contendo alguns KPIs importantes para a companhia, entre eles o percentual de crescimento de **same-store sales**. 
Esse KPI, apesar de não ser acompanhado no dia a dia pelo meu time, é extremamente importante para a companhia. Ele dá uma base sólida de crescimento — afinal, o número total de receita pode crescer naturalmente apenas por conta da abertura de novas lojas, o que mascara se a operação está de fato performando melhor ou não.
Por isso, é fundamental recortar apenas as lojas maduras (com pelo menos 13 meses de operação) na análise, evitando enxergar um crescimento que na verdade é só reflexo de expansão da rede.

Para a apresentação gerencial, precisávamos apenas do número total consolidado. Mas construí a base já na granularidade de categoria de produto, para que a mesma estrutura pudesse ser reaproveitada na construção do orçamento (budget), sem precisar refazer o levantamento de dados do zero.

## Sobre este repositório

Como os dados originais são de uma empresa real, os dados aqui foram **substituídos por uma base sintética** (`lojas.csv`, `dim_produtos.csv`, `vendas.csv`), gerada artificialmente com a ajuda do Claude apenas para reproduzir a lógica da consulta em um ambiente público. A query em si (`query_same_store_sales.sql`) preserva a lógica original de negócio.

## Arquivos

| Arquivo | Descrição |
|---|---|
| `lojas.csv` | Cadastro de lojas: código, data de abertura e data de encerramento |
| `dim_produtos.csv` | Dimensão de produtos, com categoria |
| `vendas.csv` | Transações de venda por loja, produto e data |
| `query_same_store_sales.sql` | Consulta que calcula a receita mês a mês vs. o mesmo mês do ano anterior, apenas para lojas maduras |
| `generate_data.py` | Script usado para gerar a base sintética |

---

# Nota técnica — limitações do código

- **Janela de datas fixa no código**: o intervalo de meses analisado (`2023-01-01` até `2025-12-01`) está *hardcoded* na CTE `meses`. Qualquer atualização de período exige alterar a query manualmente, em vez de receber isso como parâmetro.
- **`dt_enc` como string `'-'`**: a ausência de data de encerramento é representada pelo texto `'-'` em vez de `NULL`. Isso funciona, mas é uma modelagem frágil — exige `CASE WHEN` específico em vez de uma checagem padrão de nulo, e depende de nenhuma outra parte do pipeline usar `'-'` com outro significado.
- **Cálculo do ano/mês anterior (`ref_ly`) via subtração numérica**: o truque `CAST(ano_mes_ref AS INT) - 100` funciona porque o formato é sempre `YYYYMM` (6 dígitos), então subtrair 100 decrementa o ano mantendo o mês. É elegante, mas implícito — não é óbvio para quem lê a query pela primeira vez, e quebraria silenciosamente se o formato do campo mudasse.
- **`INNER JOIN` entre `atual` e `ly`**: meses sem contrapartida no ano anterior (por exemplo, o primeiro ano da série) são descartados silenciosamente, sem nenhum aviso. Um `LEFT JOIN` com tratamento explícito de nulo seria mais seguro para debugging.
- **`CROSS JOIN` entre lojas e meses**: a CTE `lojas_meses` cruza todas as lojas com todos os meses do período antes de filtrar. Com poucas lojas isso é irrelevante, mas em uma base com milhares de lojas e um horizonte de muitos anos, esse produto cartesiano pode se tornar custoso.
- **Granularidade de categoria não utilizada no resultado final**: a base foi montada already permitindo quebra por categoria de produto (pensando no uso futuro em orçamento), mas a query aqui entrega apenas o total agregado — o corte por categoria fica como próxima extensão natural.
- **Execução direto sobre CSV**: nesta versão de portfólio, a query lê os arquivos `.csv` diretamente via `read_csv_auto` do DuckDB, sem índices ou particionamento. Isso é adequado para demonstração, mas não reflete uma configuração de produção (nesse caso, seriam tabelas em um data lake/warehouse já otimizadas).

- **Dados sintéticos**: os números de receita, sazonalidade e comportamento de crescimento são gerados artificialmente (com leve tendência de alta e pico em novembro/dezembro) apenas para que a query tenha algo plausível para agregar — não refletem nenhum resultado real de negócio.
