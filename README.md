# EconFrames.jl

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Building on DataFrames.jl to ease the analysis of economic data.**

`EconFrames.jl` extends Julia's `DataFrames.jl` with data structures that carry metadata about currencies, data frequency, survey weights, and more. It provides tools for common tasks in empirical economics: inflation adjustment, panel data operations, handling data at different levels (e.g. individuals and households), and distributional analysis.

---

## Table of Contents

- [EconFrames.jl](#econframesjl)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Core Types](#core-types)
    - [EconFrame](#econframe)
    - [EconSet](#econset)
  - [Features](#features)
    - [Monetary Variables \& Inflation Adjustment](#monetary-variables--inflation-adjustment)
    - [Panel Data Operations](#panel-data-operations)
    - [Multi-Level Aggregation (Collapse \& Propagate)](#multi-level-aggregation-collapse--propagate)
    - [Grouping \& Quantiles](#grouping--quantiles)
    - [DataFrames.jl Compatibility](#dataframesjl-compatibility)
  - [Dependencies](#dependencies)
  - [License](#license)
  - [Author](#author)

---

## Installation

EconFrames.jl is not registered in Julia's General registry. To install it directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/TavoJGB/EconFrames.jl")
```

The package depends on companion packages [EconVariables.jl](https://github.com/TavoJGB/EconVariables.jl) and [EconStats.jl](https://github.com/TavoJGB/EconStats.jl), which are re-exported automatically.

---

## Core Types

### EconFrame

An `EconFrame` wraps a standard `DataFrame` with economic metadata. There are three concrete subtypes, each suited for a different data structure:

| Type | Description | Key Fields |
|------|-------------|------------|
| `EconCrossSection` | Single point-in-time survey | `date`, `weight_var` |
| `EconRepeatedCrossSection` | Multiple cross-sections over time | `date_var`, `weight_var` |
| `EconPanel` | Longitudinal data tracking the same subjects over time | `date_var`, `id_var`, `weight_var` |

All subtypes carry parametric metadata about the **data source**, **subject** (e.g. households, individuals), **frequency** (annual, quarterly, …), and **currency**.

```julia
using EconFrames, DataFrames, Dates

# Create a panel dataset
df = DataFrame(
    id     = repeat(1:100, inner=5),
    year   = repeat(Date.(2010:2014), outer=100),
    income = rand(500),
    weight = ones(500)
)

panel = EconPanel(
    df,
    MySource(),        # <: DataSource  (user-defined)
    Households(),      # <: DataSubject (user-defined)
    Annual(),          # <: DataFrequency
    :year,             # date variable
    :id;               # individual identifier
    currency = NominalUSD(),
    weight_var = :weight
)
```

### EconSet

An `EconSet` groups multiple related `EconFrame`s (e.g. individual-level and household-level data) and stores the linking variables between them:

```julia
es = EconSet(
    Dict(:ii => ef_individual, :hh => ef_household),
    (:ii, :hh) => :household_id   # linking variable
)
```

This enables the `collapse` and `propagate` operations described below.

---

## Features

### Monetary Variables & Inflation Adjustment

Mark columns as monetary and convert between nominal and real values using CPI data (provided by [EconVariables.jl](https://github.com/TavoJGB/EconVariables.jl)):

```julia
# Tag monetary columns
monetary_variable!(panel, [:income, :wealth])

# Convert to real 2010 dollars
to_real!(panel, cpi, 2010)

# Convert back to nominal
to_nominal!(panel, cpi)

# Change the base year
rebase!(panel, cpi, 2015)
```

When working with **multiple CPIs** for different good types (e.g. general consumption vs. housing), the package automatically matches each monetary variable to its corresponding CPI based on stored `good_type` metadata.

### Panel Data Operations

```julia
# Check if panel is balanced
is_balanced(panel)  # true / false

# Create lags and leads by individual
panel.data[!, :income_lag]  = lag(panel, :income)
panel.data[!, :income_lead] = lead(panel, :income; n=2)
```

### Multi-Level Aggregation (Collapse & Propagate)

**Collapse** aggregates from a finer level to a coarser one (e.g. individual → household):

```julia
collapse(es, :hh, :ii,
    :age    => only_head,      # value from reference person
    :income => weighted_mean,  # automatic weight injection
    :wealth => sum
)
```

**Propagate** distributes variables in the other direction (e.g. household → individual):

```julia
propagate(es, :ii, :hh,
    :house_value,
    :total_wealth => :hh_wealth   # with rename
)
```

### Grouping & Quantiles

Bin continuous variables into groups or compute weighted quantiles:

```julia
# Assign age groups based on thresholds
assign_groups!(panel, :age, 25:10:65)
# → creates :age_bin (numeric) and :age_group (label like "25-34")

# Assign wealth quantiles (bottom 50%, middle 40%, top 10%)
assign_quantiles!(panel, :wealth, [0.5, 0.9])
# → creates :wealth_rank (continuous 0–1) and :wealth_quant (label like "B50")

# Quantiles within year
assign_quantiles!(panel, :wealth, [0.5, 0.9]; by=:year)
```

### DataFrames.jl Compatibility

`EconFrame` objects support the familiar DataFrames.jl interface—all operations preserve column metadata (monetary flags, good types, etc.):

```julia
# Indexing, filtering, selecting
subset(panel, :income => x -> x .> 0)
select(panel, :id, :year, :income)
filter(:age => >(25), panel)

# Joins (metadata from both sides is preserved)
leftjoin(ef_left, ef_right; on=:id)

# GroupBy + Combine (automatically adds N and weight columns)
combine(panel, :year, :income => mean => :mean_income)

# In-place transform with metadata preservation
transform!(panel, :year, :income => (x -> x ./ mean(x)) => :income_norm)

# Sorting, renaming, dropping missing values
sort!(panel, :year)
rename!(panel, :income => :earnings)
dropmissing!(panel, :income)
```

---

## Dependencies

| Package | Purpose |
|---------|---------|
| [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) | Underlying tabular data |
| [CSV.jl](https://github.com/JuliaData/CSV.jl) | Reading / writing CSV files |
| [EconVariables.jl](https://github.com/TavoJGB/EconVariables.jl) | Economic variable types, currencies, CPI |
| [EconStats.jl](https://github.com/TavoJGB/EconStats.jl) | Statistical functions for economic data |
| [Parameters.jl](https://github.com/mauro3/Parameters.jl) | Struct unpacking with `@unpack` |
| [Reexport.jl](https://github.com/simonster/Reexport.jl) | Re-exporting companion packages |

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Author

[Gustavo García Bernal](https://garciabernal.github.io/index.html)
