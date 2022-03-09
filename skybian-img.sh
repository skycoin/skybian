#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
updpkgsums skybian.IMGBUILD
makepkg --skippgpcheck -fp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD
