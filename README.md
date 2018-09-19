# HackInTheMiddle -- calling SageMath from GAP using SCSCP hacks

the code in this repository provides a hack on top of some hacks with some hacks
to compute properties of Origamis.

This code is meant to be as a explorative prototype.

To use code in this library you need a working installation of SageMath and GAP,
both with SCSCP packages installed.

GAP comes with an SCSCP package (called SCSCP) and a WIP package
(MathInTheMiddle) that also implements the SCSCP protocol.

## How to use this hack

 1) Consider whether you really do want to do this to yourself.
 1a) to install scscp for sage run `sage --pip install scscp --user`
 2) If yes, then, run in two different terminals
 ```
  # sage orgiami_server.sage
 ```
 and
 ```
  # gap
  gap> LoadPackage("scscp");
  gap> c := NewSCSCPconnection('localhost');;
  gap> EvaluateBySCSCP("veech_group_of_origami", [ (1,2), (1,3) ], c);
```
 3) Rejoice, get a beer, and reconsider whether this is actually a good idea.
 
## Issues and Pull Requests

Feel free to use this code, or change it whichever way you like. Don't blame me
if things go wrong.
