package bootparams

import (
	"testing"

	"github.com/godbus/dbus"
	"github.com/stretchr/testify/require"
)

// TODO(evanlinjin): Maybe it's better to interact with network manager via dbus?
func TestDBus(t *testing.T) {
	conn, err := dbus.SessionBusPrivate()
	require.NoError(t, err)
	require.NoError(t, conn.Auth(nil))
	require.NoError(t, conn.Hello())
	require.NoError(t, conn.Close())
}
