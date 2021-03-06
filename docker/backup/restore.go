package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"database/sql"
	"fmt"
	"log"
	"strings"

	"cloud.google.com/go/storage"
	_ "github.com/go-sql-driver/mysql"
	"github.com/ziutek/mymysql/godrv"
)

func readToday(bucket, path string) (string, error) {
	b, err := gcsDownload(bucket, path)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func restoreMysql(fromEnv, dbHost, dbName, dbUser, dbPass, bucket, domain string, replaceDomains []string) error {
	gcsLatestPath := fmt.Sprintf("backups/%s/db/LATEST", fromEnv)
	log.Println("Retrieving LATEST from", gcsLatestPath)
	latest, err := readToday(bucket, gcsLatestPath)
	if err != nil {
		return err
	}

	gcsPath := fmt.Sprintf("backups/%s/db/%s.sql.gz", fromEnv, latest)

	sqldata, err := gcsDownload(bucket, gcsPath)
	if err != nil {
		return err
	}
	unzipped, err := gunzipFile(sqldata)
	if err != nil {
		return err
	}

	sqlstring := string(unzipped)
	for _, dom := range replaceDomains {
		log.Println("Replacing", dom, "with", domain)
		sqlstring = strings.ReplaceAll(sqlstring, dom, domain)
	}

	godrv.Register("SET NAMES utf8")
	connStr := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?multiStatements=true", dbName, dbPass, dbHost, 3306, dbName)
	db, err := sql.Open("mysql", connStr)

	_, err = db.Exec(sqlstring)
	if err != nil {
		return err
	}
	log.Println("Restored", gcsPath)
	return nil
}

func gcsDownload(bucket, src string) ([]byte, error) {

	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, err
	}
	bkt := client.Bucket(bucket)
	obj := bkt.Object(src)

	r, err := obj.NewReader(ctx)
	if err != nil {

		return nil, err
	}
	defer r.Close()
	buf := new(bytes.Buffer)
	buf.ReadFrom(r)
	return buf.Bytes(), nil
}

func gunzipFile(in []byte) ([]byte, error) {
	buf := new(bytes.Buffer)
	gz, err := gzip.NewReader(bytes.NewReader(in))
	if err != nil {
		return nil, err
	}
	defer gz.Close()
	buf.ReadFrom(gz)
	return buf.Bytes(), nil
}

func restoreUploads(fromEnv, env, bucket string) error {
	gcsLatestPath := fmt.Sprintf("backups/%s/uploads/LATEST", fromEnv)
	log.Println("Retrieving LATEST from", gcsLatestPath)
	latest, err := readToday(bucket, gcsLatestPath)
	if err != nil {
		return err
	}
	gcsPath := fmt.Sprintf("backups/%s/uploads/%s.tgz", fromEnv, latest)
	log.Println("Retrieving", gcsPath)

	uploads, err := gcsDownload(bucket, gcsPath)
	if err != nil {
		return err
	}

	err = uncompress(bytes.NewReader(uploads), "/")
	if err != nil {
		return err
	}
	return nil
}
