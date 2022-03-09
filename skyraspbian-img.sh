#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
makepkg --skippgpcheck -fp skyraspbian.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.IMGBUILD
