# JudiLingGUI

Maintainer: Maria Heitmeier

This directory contains a graphical user interface for [JudiLing](https://github.com/MegamindHenry/JudiLing.jl) and [JudiLingMeasures](https://github.com/MariaHei/JudiLingMeasures.jl).
JudiLing is a computational implementation of Linear Discriminative Learning (Baayen et al., 2018, Baayen et al., 2019, Heitmeier et al., 2021).

The latin dataset in `dat/latin.csv` was first introduced in Baayen et al., 2018.

## How to get it running

Navigate to root of the JudiLingGUI directory, start julia and run

```
pkg> activate .
pkg> instantiate
julia> include("JudiLingGUI.jl")
julia> up()
```

then go to http://localhost:8000/
(Note that it takes a bit of time when being loaded for the first time after compilation, hang in there.)

## References

Baayen, R. H., Chuang, Y. Y., and Blevins, J. P. (2018). Inflectional morphology with linear mappings. The Mental Lexicon, 13 (2), 232-270.

Baayen, R. H., Chuang, Y. Y., Shafaei-Bajestan, E., and Blevins, J. P. (2019). The discriminative lexicon: A unified computational model for the lexicon and lexical processing in comprehension and production grounded not in (de)composition but in linear discriminative learning. Complexity, 2019, 1-39.

Heitmeier, M., Chuang, Y-Y., Baayen, R. H. (2021). Modeling morphology with Linear Discriminative Learning: considerations and design choices. Frontiers in Psychology, 12, 4929.
