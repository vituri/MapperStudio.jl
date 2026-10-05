# Ayasdi Mapper: research and correspondences

Reviewed on **3 October 2026**. This is a reconstruction of functionality from
historical public sources, rather than a complete specification of the
proprietary product. Search-engine indexing dates are not publication dates.
Some older blogs are unavailable at their original addresses; some articles
moved to SymphonyAI. No complete, accessible SDK manual was found that would
allow every method name, limit or behavior to be reconstructed.

## 1. The product was a platform

The 2017 whitepaper describes a technology layer served through REST, three
access paths and Hadoop-oriented infrastructure. **Workbench** was the visual
application for building and exploring models; the **Python SDK** provided
programmatic access to a broader surface; **Envision** supplied components and
workflows for business applications. The company also combined discovery,
prediction, justification, action and learning. Reproducing a graph drawing
alone would therefore leave much of the product workflow unimplemented.
Primary source: [Understanding Ayasdi, pp. 6–8](https://s3.amazonaws.com/cdn.ayasdi.com/wp-content/uploads/2018/04/04142230/UnderstandingAyasdi_WP_061617v011.pdf).

## 2. Building the topological model

The workflow selected variables and a dissimilarity measure, computed lenses,
covered lens space with overlapping intervals, clustered each preimage and
connected clusters with shared observations. The resulting graph summarized
branches, components and loops without requiring a single global partition.
The lens determines the cover; the metric determines similarity within it;
the layout determines the drawn position. These are separate decisions.

Publicly documented controls include **resolution**, the number of intervals;
**gain**, with relative overlap `1 − 1/gain`; and **equalize**, which attempts to
balance the number of observations in preimages. Gain 2 corresponds to 50%
overlap; gain 3 to approximately 66.7%. PCA and MDS appeared as lenses; the
Neighborhood lenses used a k-NN graph and a proprietary embedding. The paper
recommends using the Neighborhood pair together and avoiding equalization in
that case. Metrics include Euclidean, correlation and normalized variants.
Primary source: [Pirashvili et al., Journal of Cheminformatics (2018), Implementation of mapper](https://doi.org/10.1186/s13321-018-0308-5).

Neighborhood should not be identified with an arbitrary generic t-SNE
implementation: the paper describes a proprietary construction. Likewise,
“normalized” does not specify a unique formula across versions. In the Studio,
standard-deviation scaling is an explicit, audited choice; numerical identity
with all historical VNE variants is not claimed.

## 3. Visual exploration and Explain

Coloring nodes by a variable, highlighting regions and examining what
distinguishes them forms the central workflow illustrated in the linked
article. It collects applications involving financial regimes, claim denials,
fraud, oil exploration, social-media conversations and biomarkers. It describes
networks built from millions of records, without providing a reproducible
benchmark of computational costs. Color is an investigative variable: it might
represent an outcome, date, payment, word or model error while geometry is
constructed from other features.
Discovery source: [Skycak, Mapper Use-Cases at Ayasdi (2017)](https://www.justinmath.com/mapper-use-cases-at-ayasdi/).

In Gunnar Carlsson's published explanation, two groups produce two
distributions for each variable. **Explain** ranks variables by the
Kolmogorov–Smirnov statistic and presents p-values. The article also describes
an extension: transpose the matrix to build Mapper on **variables**, then color
that map with the mean values of a group of observations. This second map helps
organize a long list of correlated features.
Primary source: [Carlsson, Machine Intelligence for Statistical Inference and Human Interpretation of Data (2018)](https://www.symphonyai.com/resources/machine-intelligence-statistical-inference-human-interpretation-data).

The Studio provides KS for numeric variables, total-variation distance for
categories, seeded permutation p-values, mean differences, standardized effect
sizes and Benjamini–Hochberg q-values. This is an **adaptation**, without a claim
of equivalence to the tests in every Ayasdi version. Selections and references
are deduplicated sets of rows; an explicit reference excludes the intersection.
Groups chosen after examining the same data introduce selection bias that BH
does not remove. The analysis is labeled exploratory.

## 4. Automatic groups, hotspots and predictive models

A study of prediction failures describes subgroups selected manually or through
community detection; the Ayasdi implementation combines agglomerative
hierarchical clustering with Louvain modularity. It also uses prediction error
as a lens to collect failure modes. This capability is richer than separating
connected components alone.
Primary source: [Fibers of Failure: Classifying Errors in Predictive Processes (2020)](https://www.mdpi.com/1999-4893/13/6/150).

The AML whitepaper describes customer/transaction segmentation, anomaly
discovery, hotspot identification, alert ranking and updates as new data arrive.
Justification includes decision trees and documentation for model evaluation.
These are workflows in a specialized application built on the platform; there
is no evidence that every button was available in the generic Workbench.
Primary source: [Anti-Money Laundering Solution Deep Dive (2017/2018), Intelligent Segmentation/Alerts/Typologies](https://s3.amazonaws.com/cdn.ayasdi.com/wp-content/uploads/2018/04/22170635/AML_Solutions_Deep_Dive_WP_051617v01.pdf).

The Studio implements groups based on connected components, hotspots defined
by the upper quartile of the numeric color, and ToMATo on the point cloud.
Hotspots are descriptive. None of these methods is presented as a copy of
AHCL/Louvain autogrouping or enterprise alert ranking.

## 5. Automation, data types and scale

The SymphonyAI whitepaper advertises automatic model construction with search
over metrics and filters, numeric and sparse text data, millions of rows, many
columns, SDK/API integration, high availability, user management, collaboration
and multiple clients. It also describes feature discovery, recommendations and
local models or ensembles in segments. These are vendor claims, rather than
independent measurements that establish the same results for the Studio.
Primary source: [Topological Data Analysis and Machine Learning: Better Together (2020), pp. 13–15](https://www.symphonyai.com/wp-content/uploads/2020/07/SAI-Topological-Data-Analysis-and-Machine-Learning-Better-Together-vf.pdf).

The Studio's sweep compares cover configurations while keeping lenses, metric
and preprocessing fixed. It does not learn which model is optimal. The local
version keeps up to eight tables and sixteen recent results in memory;
workspace export provides persistent recovery.

## 6. Feature matrix for this implementation

| Area | Implemented in the Studio | Difference or limit |
|---|---|---|
| Data | CSV/TSV, numeric/categorical types, quality, search, table, missing values | Dense numeric geometry, up to 3,000 rows and 80 variables |
| Preprocessing | Standard, robust/IQR, min–max, original; rejection or median imputation | Preserves original values and records each transformation |
| Metrics | Euclidean, Manhattan, Chebyshev, cosine, correlation | Cosine/correlation require appropriate rows; dissimilarities are not all strict metrics |
| Lenses | PCA, MDS with up to 200 landmarks, diffusion, mean/maximum eccentricity, kNN, Gaussian, norm, index, column | Diffusion up to 600 rows; proprietary Neighborhood lenses are not reproduced |
| Mapper | Classic Mapper with one/two lenses, Ball Mapper, uniform/equalized intervals | Exact gain in value or rank space; ties prevent all counts from being equalized |
| Clustering | First empty bin, DBSCAN, single/complete/average linkage, K-means, trivial | Euclidean, deterministic K-means; DBSCAN noise becomes singletons |
| Edges | Intersection and Jaccard | Graph is the 1-skeleton; E−V+C does not represent point-cloud PH |
| Exploration | Pan/zoom, drag, rectangular/keyboard selection, linked projection, color and size, four layouts | Layout changes presentation, not memberships |
| Populations | Deduplicated selections, names, references between groups, Explain and distributions | Exploratory tests; references remove shared rows |
| Comparison | Resolution/gain sweeps, model snapshots | Up to 20 configurations per run; no stability or optimality guarantee |
| PH | Rips in the selected metric; diagram, barcode, Betti, entropy and exportable landmarks | F₂; H0/H1 up to 300 landmarks; H2 up to 80; zero-distance duplicates are identified |
| Topological clustering | ToMATo, k-NN graph, density and groups | τ in density units; does not reproduce the proprietary algorithm |
| Temporal | Delay embedding and sliding-window PH | Row order; regularly spaced samples; up to 25 windows |
| Images | Grayscale, height, radial, dilation, erosion, signed distance; cubical PH and Euler | Explicit resizing to at most 96×96; lower-star on vertices |
| Multiparameter | Function-Rips, Hilbert and Euler on a grid | Euclidean, F₂, up to 28 landmarks, 10×10; dense reference algorithm |
| Reproducibility | Workspace JSON, CSV, graph JSON/SVG, results JSON, Julia script with embedded data | Isolated dependencies; the server never executes received code |
| Integration | Documented Julia API and local REST | No accounts, remote collaboration, Hadoop or distributed cluster |

## 7. Concrete next steps

1. Performance validation for sparse matrices and large tables, distance caching,
   distributed clustering and WebGL rendering for large networks.
2. More native ecosystem lenses and covers, modularity-based communities,
   variable maps and aligned comparison between models.
3. Interfaces for Alpha/Witness, representative cycles, circular coordinates,
   vectorized diagrams, bootstrap inference and trainable filters.
4. On-disk projects, cancellable queues, per-operation provenance logs,
   authentication and collaboration when remote use is needed.
5. Evaluation with real tasks, users and benchmarks against public
   implementations. “The most beautiful/complete” is a product direction,
   rather than a position demonstrated by this first release.

The corresponding scientific APIs already available in JuliaTDA remain
accessible from Julia. Interface coverage should not be confused with the
coverage of the entire library.
