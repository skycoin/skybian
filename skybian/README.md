Builds requires archlinux host.

### Skybian image:

install dependencies from AUR:
```
yay -S gnome-disk-utility qemu-arm-static aria2 file-roller
```

Note: be sure to install qemu-arm-static-bin if you don't have qemu-arm-static installed already

Build:
```
 makepkg --skippgpcheck -p IMGBUILD
```

### Skybian package:

install dependencies from AUR:
```
yay -S dpkg
```

Build:
```
makepkg
```
