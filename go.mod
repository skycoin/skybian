module github.com/skycoin/skybian

// go 1.14 presents problems for fyne so 1.13 is used.
go 1.16

require (
	fyne.io/fyne/v2 v2.1.0
	github.com/google/go-github v17.0.0+incompatible
	github.com/mholt/archiver v3.1.1+incompatible
	github.com/rakyll/statik v0.1.7
	github.com/sirupsen/logrus v1.8.1
	github.com/skratchdot/open-golang v0.0.0-20200116055534-eef842397966
	github.com/skycoin/dmsg v0.0.0-20211007145032-962409e5845f
	github.com/skycoin/skycoin v0.27.1
	github.com/skycoin/skywire v0.5.1
	github.com/stretchr/testify v1.6.1
	golang.org/x/net v0.0.0-20210405180319-a5a99cb37ef4
)

// Uncomment it for tests with alternative branches and run `make dep`

// replace github.com/skycoin/skywire => ../skywire
