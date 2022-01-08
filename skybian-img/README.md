Build requires archlinux host.

install dependencies from AUR:
```
yay -S 'gnome-disk-utility' 'qemu-arm-static' 'aria2' 'file-roller'
```

Note: be sure to install qemu-arm-static-bin if you don't have qemu-arm-static installed already

Build:
```
 makepkg --skippgpcheck -p IMGBUILD
```
