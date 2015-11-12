# d-sas7bdat
SAS inconveniently doesn't provide a specification for their propietary dataset format sas7bdat.
This can lock people into SAS when they'd rather have alternatives. That said, they're difficulties 
in just dropping support, so having the ability to both read and write is fairly crucial. For this implementation I plan
to overcome a lot of these hurdles, but fortuantely I'm not starting from scratch. There's a fairly well documented 
reverse engineering effort, as well as implmentations in R, Java, Python, and C.

As far as I'm aware, people have not previously tried to write SAS datasets.


## features
* Reads sas7bdat files

## planned features
* Write sas7bdat files
* Provide files as streams

## references

* [Unoffical sas7bdat specification](https://cran.r-project.org/web/packages/sas7bdat/vignettes/sas7bdat.pdf)
* [Java library that this library is mostly based on](https://github.com/datacleaner/metamodel_extras/tree/master/sas/src/main/java/org/eobjects/metamodel/sas)
* [R](https://cran.r-project.org/web/packages/sas7bdat/index.html)
* [Python](https://bitbucket.org/jaredhobbs/sas7bdat)
* [C](https://github.com/WizardMac/ReadStat)
