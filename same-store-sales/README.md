# Same-Store Sales

## Contexto de negócio

Havia uma necessidade recorrente de negócio: todo mês, o time precisava apresentar um material gerencial para a alta gestão contendo alguns KPIs importantes para a companhia, entre eles o percentual de crescimento de **same-store sales**.

Historicamente, esse KPI era apurado pela equipe de Finanças de forma totalmente manual por meio de planilhas de Excel. Para eliminar o retrabalho, mitigar riscos operacionais e dar autonomia ao nosso time — evitando depender do fechamento e da disponibilidade de outra área —, conduzi o mapeamento de todo o passo a passo e das regras de negócio junto ao time financeiro. 

A partir desse entendimento, estruturei a automação da consulta para consumir os dados transacionais de venda diretamente do **Data Lake**. Como o Data Lake era atualizado com defasagem de apenas **D-1**, essa abordagem permitiu que tivéssemos o indicador consolidado e validado logo no primeiro dia após o fechamento do mês, encurtando significativamente o tempo de entrega do material para a diretoria.

Esse KPI, apesar de não ser acompanhado no dia a dia da nossa operação, é estratégico para a companhia por fornecer uma base sólida de crescimento orgânico. O faturamento total pode subir apenas pela abertura de novas unidades, o que mascara se os pontos de venda existentes estão de fato performando melhor. Por isso, é fundamental recortar apenas as lojas maduras (com pelo menos 13 meses de operação), isolando o efeito da expansão da rede.

Para a apresentação gerencial, precisávamos apenas do número total consolidado. Contudo, estruturei a base já na granularidade de categoria de produto, permitindo que a mesma lógica seja reaproveitada em outros processos (como a elaboração anual do *orçamento*), sem a necessidade de reconstruir o levantamento do zero.

## Sobre este repositório

Como os dados originais são de uma empresa real, os dados aqui foram **substituídos por uma base sintética** (`lojas.csv`, `dim_produtos.csv`, `vendas.csv`), gerada artificialmente com o auxílio do Claude, apenas para reproduzir a lógica da consulta em um ambiente público. A query em si (`query_same_store_sales.sql`) preserva a lógica original de negócio.

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
- **Granularidade de categoria não utilizada no resultado final**: a base foi montada permitindo quebra por categoria de produto (pensando no uso futuro em orçamento), mas a query aqui entrega apenas o total agregado — o corte por categoria fica como próxima extensão natural.
- **Execução direto sobre CSV**: nesta versão de portfólio, a query lê os arquivos `.csv` diretamente via `read_csv_auto` do DuckDB, sem índices ou particionamento. Isso é adequado para demonstração, mas não reflete uma configuração de produção (onde a query rodaria diretamente sobre as tabelas do Data Lake).
- **Dados sintéticos**: os números de receita, sazonalidade e comportamento de crescimento são gerados artificialmente (com leve tendência de alta e pico em novembro/dezembro) apenas para que a query tenha algo plausível para agregar — não refletem nenhum resultado real de negócio.
