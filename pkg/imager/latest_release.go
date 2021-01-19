package imager

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/google/go-github/github"
	"github.com/sirupsen/logrus"
)

const (
	ghOwner            = "skycoin"
	ghRepo             = "skybian"
	repoRequestTimeout = 5 * time.Second
)

func expectedBaseImgAssetName(t ImgType, tag string) string {
	var filename string
	switch t {
	case TypeRaspbian:
		filename = "SkyRaspbian"
	case TypeSkybian:
		filename = "Skybian"
	default:
		panic(fmt.Sprintf("unknown image type: %v", t))
	}
	return fmt.Sprintf("%s-%s%s", filename, tag, ExtTarGz)
}

// LatestBaseImgURL returns the latest stable base image download URL.
func LatestBaseImgURL(ctx context.Context, t ImgType, log logrus.FieldLogger) (string, error) {
	gh := github.NewClient(nil)
	release, _, err := gh.Repositories.GetLatestRelease(ctx, ghOwner, ghRepo)
	if err != nil {
		return "", err
	}

	tag := release.GetTagName()
	log.WithField("tag", tag).
		Debug("Got tag.")

	name := expectedBaseImgAssetName(t, tag)
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

// TimeFormat is our default time format.
const TimeFormat = "2006/01/02 15:04"

// Release represents a base image release obtained from GitHub.
type Release struct {
	Tag  string
	Type string // stable, prerelease
	Date time.Time
	URL  string
}

// String implements io.Stringer
func (r *Release) String() string {
	if r == nil {
		return ""
	}
	return fmt.Sprintf("%s (%s) (%s)",
		r.Tag, r.Type, r.Date.Format(TimeFormat))
}

func releaseURL(releases []Release, releaseStr string) (string, error) {

	tag, err := bytes.NewBufferString(releaseStr).ReadString(' ')
	if err != nil {
		return "", err
	}
	tag = strings.TrimSpace(tag)

	for _, r := range releases {
		if r.Tag != tag {
			continue
		}
		return r.URL, nil
	}

	return "", fmt.Errorf("release of tag '%s' no longer available", tag)
}

func releaseStrings(releases []Release) (rs []string) {
	rs = make([]string, len(releases))
	for i, r := range releases {
		rs[i] = r.String()
	}
	return rs
}

// ErrNetworkConn is returned when it's impossible to make a request due to the network failure
var ErrNetworkConn = errors.New("Network connection error")

// ListReleases obtains a list of base image releases.
// The output 'latest' is non-nil when a latest release is found.
func ListReleases(ctx context.Context, t ImgType, log logrus.FieldLogger) (rs []Release, latest *Release, err error) {
	gh := github.NewClient(nil)
	ctx, cancel := context.WithTimeout(ctx, repoRequestTimeout)
	defer cancel()
	ghRs, _, err := gh.Repositories.ListReleases(ctx, ghOwner, ghRepo, nil)
	var dnsErr *net.DNSError
	if ok := errors.As(err, &dnsErr); ok {
		log.Error("Error fetching latest releases: can't resolve address")
		return nil, nil, ErrNetworkConn
	}
	if ctx.Err() == context.DeadlineExceeded {
		log.Error("Error fetching latest releases: network timeout")
		return nil, nil, ErrNetworkConn
	}
	if err != nil {
		return nil, nil, err
	}

	for _, r := range ghRs {
		if r.GetDraft() {
			continue
		}

		exp := expectedBaseImgAssetName(t, r.GetTagName())
		for _, asset := range r.Assets {
			if asset.GetName() != exp {
				continue
			}

			rInfo := Release{
				Tag:  r.GetTagName(),
				Type: "stable",
				Date: r.GetCreatedAt().Time,
				URL:  asset.GetBrowserDownloadURL(),
			}
			if r.GetPrerelease() {
				rInfo.Type = "prerelease"
			} else {
				if latest == nil || rInfo.Date.After(latest.Date) {
					latest = &rInfo
				}
			}

			log.WithField("info", rInfo).Info("Found release.")
			rs = append(rs, rInfo)
			break
		}
	}

	return rs, latest, nil
}
