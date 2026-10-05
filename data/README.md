# Reaven–Miller diabetes example

`diabetes.csv` contains the 145 observations distributed by the R packages
[`rrcov`](https://github.com/cran/rrcov) and
[`loon.data`](https://github.com/cran/loon.data). The numeric values and class
labels were independently compared during the JuliaTDA Mapper 2007 reproduction.
`patient_id` is the original row position. Historical classes are annotations,
not modern diagnostic labels. Age was not available and is not imputed.

References: Reaven and Miller (1979), *Diabetologia* 16:17–24;
Andrews and Herzberg (1985), Chapter 36, Table 36.1. Upstream data retain their
original attribution and terms; the application code's MIT license does not
relicense these data.

[`provenance.toml`](provenance.toml) preserves the fixed upstream URLs, SHA256
checksums and verification record. Its `raw/` filenames describe the original
reproduction downloads; those downloads are not needed or bundled in this app.
