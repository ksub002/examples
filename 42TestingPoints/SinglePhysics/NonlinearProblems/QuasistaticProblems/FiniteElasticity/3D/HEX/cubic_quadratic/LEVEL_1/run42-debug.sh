#!/bin/bash
$OPENCMISS_ROOT/cm/examples/FiniteElasticity/testingPoints/bin/x86_64-linux/mpich2/gnu_4.4/testingPointsExample-debug  -DIM=3D -ELEM=HEX -BASIS_1=cubic -BASIS_2=quadratic -LEVEL=1 -snes_ls quadratic
#mv *.exnode *.exelem output/
