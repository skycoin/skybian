package imager

import (
	"context"
	"fmt"
	"testing"

	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
)

func TestListReleases(t *testing.T) {
	ctx := context.Background()
	log := logrus.New()
	out, _, err := ListReleases(ctx, TypeSkybian, log)
	require.NoError(t, err)
	for i, v := range out {
		fmt.Printf("[%d]\n", i)
		fmt.Println(v)
	}
}
