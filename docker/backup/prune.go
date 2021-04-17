package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

func pruneBackups(bucket, app, typ string) error {
	tenDaysAgo := time.Now().Add(-10 * 24 * time.Hour)
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return err
	}
	bkt := client.Bucket(bucket)
	query := &storage.Query{Prefix: fmt.Sprintf("backups/%s/%s", app, typ)}
	it := bkt.Objects(ctx, query)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if attrs.Name == "LATEST" {
			continue
		}
		if err != nil {
			return err
		}
		_, _, day := attrs.Created.Date()
		if attrs.Created.Before(tenDaysAgo) && day != 1 {
			log.Printf("Deleting %s/%s/%s", app, typ, attrs.Name)
			bkt.Object(attrs.Name).Delete(ctx)
			if err != nil {
				return err
			}
		}
	}

	return nil
}
