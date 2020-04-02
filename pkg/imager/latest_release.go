package imager

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/go-github/github"
	"github.com/sirupsen/logrus"
)

const (
	ghOwner = "SkycoinProject"
	ghRepo  = "skybian"
)

func expectedBaseImgAssetName(tag string) string {
	return fmt.Sprintf("Skybian-%s%s", tag, ExtTarXz)
}

func LatestBaseImgURL(ctx context.Context, log logrus.FieldLogger) (string, error) {
	gh := github.NewClient(nil)
	release, _, err := gh.Repositories.GetLatestRelease(ctx, ghOwner, ghRepo)
	if err != nil {
		return "", err
	}

	tag := release.GetTagName()
	log.WithField("tag", tag).
		Debug("Got tag.")

	name := expectedBaseImgAssetName(tag)
	log.WithField("expected_name", name).
		Info("Expecting asset of name.")

	for _, asset := range release.Assets {
		if asset.GetName() != name {
			log.WithField("got", asset.GetName()).
				WithField("expected", name).
				Debug("Name does not satisfy.")
			continue
		}
		return asset.GetBrowserDownloadURL(), nil
	}
	return "", errors.New("latest release of Skybian Base Image cannot not found")
}
