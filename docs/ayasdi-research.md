# O Mapper da Ayasdi: investigação e correspondências

Consultado em **3 de outubro de 2026**. Esta é uma reconstrução de funcionalidades
a partir de fontes públicas históricas, não uma especificação completa do produto
proprietário. Datas de indexação dos buscadores não são datas de publicação. Parte
dos blogs antigos está indisponível no endereço original; alguns textos migraram
para a SymphonyAI. Não foi encontrado um manual completo e acessível do SDK que
permitisse reconstruir todos os nomes de métodos, limites ou comportamentos.

## 1. O produto era uma plataforma, não apenas um algoritmo

O whitepaper de 2017 descreve uma camada de tecnologia servida por REST, três
formas de acesso e uma infraestrutura orientada a Hadoop. **Workbench** era a
aplicação visual para construir e explorar modelos; **Python SDK** dava acesso
programático a uma superfície mais ampla; **Envision** fornecia componentes e
fluxos para aplicações de negócio. A empresa também combinava descoberta,
predição, justificação, ação e aprendizado. Portanto, clonar apenas um desenho
de grafo não reconstruiria o fluxo do produto.
Fonte primária: [Understanding Ayasdi, pp. 6–8](https://s3.amazonaws.com/cdn.ayasdi.com/wp-content/uploads/2018/04/04142230/UnderstandingAyasdi_WP_061617v011.pdf).

## 2. Construção do modelo topológico

O fluxo selecionava variáveis e uma medida de dissimilaridade, calculava lentes,
cobria seu espaço com intervalos sobrepostos, fazia clustering em cada
pré-imagem e conectava clusters com observações compartilhadas. O grafo resumido
permitia ver ramos, componentes e laços, sem exigir uma única partição global.
A lente determina a cobertura; a métrica determina semelhança dentro dela;
o layout determina a posição desenhada. São decisões diferentes.

Os controles publicamente documentados incluem **resolution**, número de
intervalos; **gain**, com sobreposição relativa `1 − 1/gain`; e **equalize**,
que procura equilibrar o número de observações nas pré-imagens. Ganho 2
corresponde a 50%; ganho 3, aproximadamente 66,7%. PCA e MDS apareciam como
lentes; as chamadas Neighborhood lenses usavam um grafo k-NN e embedding
proprietário. O artigo recomenda usar o par Neighborhood em conjunto e evitar
equalização nesse caso. Há métricas euclidiana, correlação e versões normalizadas.
Fonte primária: [Pirashvili et al., Journal of Cheminformatics (2018), Implementation of mapper](https://doi.org/10.1186/s13321-018-0308-5).

Não se deve identificar Neighborhood com qualquer implementação genérica de
t-SNE: o texto descreve uma construção proprietária. Tampouco a palavra
"normalizada" basta para fixar uma fórmula entre versões. No Studio, padronização
por desvio padrão é uma escolha explícita e auditada; não se afirma identidade
numérica com todas as variantes históricas VNE.

## 3. Exploração visual e Explain

Colorir nós por uma variável, destacar regiões e examinar o que as distingue
constitui o fluxo central ilustrado no artigo indicado pelo usuário. O artigo
reúne aplicações a regimes financeiros, recusas de contas, fraude, exploração
de petróleo, conversas em redes sociais e biomarcadores. Seu relato inclui
redes construídas de milhões de registros, mas não oferece um benchmark
reproduzível dos custos computacionais. A coloração é uma variável de
investigação: pode ser desfecho, data, pagamento, palavra ou erro de um modelo,
enquanto a geometria é construída com outras características.
Fonte de descoberta: [Skycak, Mapper Use-Cases at Ayasdi (2017)](https://www.justinmath.com/mapper-use-cases-at-ayasdi/).

Na explicação publicada por Gunnar Carlsson, dois grupos dão origem a duas
distribuições para cada variável. **Explain** ordena as variáveis pela
estatística Kolmogorov–Smirnov e apresenta valores p. O texto também descreve
uma extensão: transpor a matriz para fazer Mapper das **variáveis**, e colorir
esse mapa com os valores médios de um grupo de observações. Esse segundo mapa
ajuda a organizar uma lista longa de características correlacionadas.
Fonte primária: [Carlsson, Machine Intelligence for Statistical Inference and Human Interpretation of Data (2018)](https://www.symphonyai.com/resources/machine-intelligence-statistical-inference-human-interpretation-data).

O Studio oferece KS para variáveis numéricas, distância de variação total para
categorias, valores p por permutação com semente, diferenças de médias, efeito
padronizado e q de Benjamini–Hochberg. Isso é uma **adaptação**, não uma alegação
de equivalência dos testes de todas as versões da Ayasdi. Seleções e referências
são conjuntos de linhas, deduplicados; uma referência explícita exclui a
interseção. Grupos escolhidos depois de olhar estes mesmos dados produzem viés
de seleção que BH não remove. A análise é identificada como exploratória.

## 4. Grupos automáticos, hotspots e modelos preditivos

Um estudo de falhas de predição descreve subgrupos escolhidos manualmente ou
por detecção de comunidades; a implementação Ayasdi combina clustering
hierárquico aglomerativo com modularidade Louvain. Usa ainda o erro de predição
como lente para reunir modos de falha. Essa capacidade é mais rica do que
apenas separar componentes conectadas.
Fonte primária: [Fibers of Failure: Classifying Errors in Predictive Processes (2020)](https://www.mdpi.com/1999-4893/13/6/150).

O whitepaper AML descreve segmentação de clientes/transações, descoberta de
anomalias, identificação de hotspots, ranking de alertas e atualizações diante
de novos dados. A justificação inclui árvores de decisão e documentação para
avaliação dos modelos. Esses são fluxos de uma aplicação especializada,
construída sobre a plataforma; não há evidência de que todo botão estivesse
disponível no Workbench genérico.
Fonte primária: [Anti-Money Laundering Solution Deep Dive (2017/2018), Intelligent Segmentation/Alerts/Typologies](https://s3.amazonaws.com/cdn.ayasdi.com/wp-content/uploads/2018/04/22170635/AML_Solutions_Deep_Dive_WP_051617v01.pdf).

O Studio implementa grupos por componentes, hotspots definidos pelo quartil
superior da cor numérica e ToMATo na nuvem de dados. Os hotspots são
descritivos. Nenhum desses métodos é apresentado como cópia do autogrouping
AHCL/Louvain ou do ranking empresarial de alertas.

## 5. Automação, tipos de dados e escala

O whitepaper da SymphonyAI anuncia construção automática de modelos com
busca sobre métricas e filtros, dados numéricos e texto esparso, milhões de
linhas, muitas colunas, integração por SDK/API, alta disponibilidade,
gerenciamento de usuários, colaboração e múltiplos clientes. Também descreve
descoberta de características, recomendações e modelos locais ou ensembles
em segmentos. São afirmações do fabricante, não medições independentes que
permitam atribuir esses mesmos resultados ao Studio.
Fonte primária: [Topological Data Analysis and Machine Learning: Better Together (2020), pp. 13–15](https://www.symphonyai.com/wp-content/uploads/2020/07/SAI-Topological-Data-Analysis-and-Machine-Learning-Better-Together-vf.pdf).

A varredura do Studio compara configurações de cobertura mantendo lentes,
métrica e pré-processamento fixos. Ela não aprende qual modelo é ótimo. A
versão local mantém até oito tabelas e dezesseis resultados recentes em
memória; exportar workspace é o mecanismo persistente de recuperação.

## 6. Mapa de funcionalidades desta implementação

| Área | Implementado no Studio | Diferença ou limite |
|---|---|---|
| Dados | CSV/TSV, tipos numéricos/categóricos, qualidade, busca, tabela, valores ausentes | Geometria numérica densa, até 3.000 linhas e 80 variáveis |
| Pré-processamento | Padrão, robusto/IQR, min–max, original; rejeição ou mediana | Preserva os valores originais e registra cada transformação |
| Métricas | Euclidiana, Manhattan, Chebyshev, cosseno, correlação | Cosseno/correlação requerem linhas apropriadas; dissimilaridades não são todas métricas estritas |
| Lentes | PCA, MDS com até 200 marcos, difusão, excentricidade média/máxima, kNN, gaussiana, norma, índice, coluna | Difusão até 600 linhas; Neighborhood proprietário não reproduzido |
| Mapper | Clássico em uma/duas lentes, Ball Mapper, intervalos uniformes/equalizados | Gain exato no espaço de valores ou postos; empates impedem igualar todas as contagens |
| Clustering | Primeiro bin vazio, DBSCAN, ligação simples/completa/média, K-means, trivial | K-means euclidiano e determinístico; ruído DBSCAN vira singleton |
| Conexões | Interseção e Jaccard | Grafo é o 1-esqueleto; o número E−V+C não representa PH da nuvem |
| Exploração | Pan/zoom, arrasto, seleção retangular/teclado, projeção ligada, cor e tamanho, quatro layouts | Layout altera apresentação, não memberships |
| Populações | Seleções deduplicadas, nomes, referência entre grupos, Explain e distribuições | Testes exploratórios; referência remove linhas em comum |
| Comparação | Varredura de resolução/ganho, snapshots de modelos | Até 20 configurações por execução; sem garantia de estabilidade ou optimalidade |
| PH | Rips na métrica selecionada; diagrama, barcode, Betti, entropia e marcos exportáveis | F₂; H0/H1 até 300 marcos; H2 até 80; duplicatas de distância zero são identificadas |
| Clustering topológico | ToMATo, grafo k-NN, densidade e grupos | τ em unidades de densidade; não equivale ao algoritmo proprietário |
| Temporal | Embedding por atrasos e PH em janelas | Ordem de linhas; amostras regulares; até 25 janelas |
| Imagens | Cinza, altura, radial, dilatação, erosão, distância assinada; PH cubical e Euler | Redução explícita a até 96×96; lower-star em vértices |
| Multiparâmetro | Function-Rips, Hilbert e Euler em grade | Euclidiano, F₂, até 28 marcos, 10×10; algoritmo de referência denso |
| Reprodutibilidade | Workspace JSON, CSV, grafo JSON/SVG, resultados JSON, script Julia com dados incorporados | Dependências locais separadas; nenhum código recebido é executado pelo servidor |
| Integração | API Julia e REST local documentadas | Sem contas, colaboração remota, Hadoop ou cluster distribuído |

## 7. Próximas etapas concretas

1. Validação de desempenho para matrizes esparsas e grandes tabelas, caching de
   distâncias, clustering distribuído e renderização WebGL para redes grandes.
2. Mais lentes e coberturas nativas do ecossistema, comunidades com modularidade,
   mapas das variáveis e comparação alinhada entre modelos.
3. Interfaces para Alpha/Witness, ciclos representativos, coordenadas circulares,
   diagramas vetorizados, inferência por bootstrap e filtros treináveis.
4. Projetos em disco, filas canceláveis, logs de proveniência por operação,
   autenticação e colaboração quando houver demanda por uso remoto.
5. Avaliações com tarefas reais, usuários e benchmarks contra implementações
   públicas. "O mais bonito/completo" é uma direção de produto, não uma posição
   demonstrada por esta primeira versão.

As APIs científicas correspondentes já existentes em JuliaTDA continuam
acessíveis em Julia. A cobertura da interface não deve ser confundida com a
cobertura de toda a biblioteca.
