module github.com/skycoin/skybian

// go 1.14 presents problems for fyne so 1.13 is used.
go 1.13

require (
	fyne.io/fyne v1.4.0
	github.com/go-gl/glfw v0.0.0-20181213070059-819e8ce5125f // indirect
	github.com/google/go-github v17.0.0+incompatible
	github.com/mholt/archiver v3.1.1+incompatible
	github.com/rakyll/statik v0.1.7
	github.com/sirupsen/logrus v1.6.0
	github.com/skratchdot/open-golang v0.0.0-20200116055534-eef842397966
	github.com/skycoin/dmsg v0.0.0-20201018132543-a08c07be4640
	github.com/skycoin/skycoin v0.26.0
	github.com/skycoin/skywire v0.3.0
	github.com/stretchr/testify v1.6.1
	golang.org/x/mobile v0.0.0-20190719004257-d2bd2a29d028 // indirect
	nhooyr.io/websocket v1.8.4 // indirect
)

// Uncomment it for tests with alternative branches and run `make dep`

replace github.com/skycoin/skywire => ../skywire
