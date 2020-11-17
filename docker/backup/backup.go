package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"time"

	"cloud.google.com/go/storage"
)

func backupMysql(dbHost, dbName, dbUser, dbPass, bucket string) error {

	out, err := exec.Command("mysqldump", "-u", dbUser, "-p"+dbPass, "-h", dbHost, dbName).Output()
	if err != nil {
		panic(err)
	}
	zippedData, err := gzipFile(out)
	if err != nil {
		return err
	}
	log.Println("Zipped", len(zippedData), "bytes")

	today := getToday()
	gcsPath := fmt.Sprintf("backups/%s/db/%s.sql.gz", dbName, today)

	log.Println("Writing to", gcsPath)
	err = gcsUpload(zippedData, bucket, gcsPath)
	if err != nil {
		return err
	}
	gcsLatestPath := fmt.Sprintf("backups/%s/db/LATEST", dbName)
	log.Println("Writing LATEST to", gcsLatestPath)
	return writeToday(today, bucket, gcsLatestPath)
}

const timefmt = "2006/01/02 15:04:05"

func backupFile(dbName, path, bucket string, newerThanSeconds int) error {

	afterTime := time.Now().Add(time.Second * time.Duration(-newerThanSeconds)).Unix()
	d, err := os.Open(path)
	if err != nil {
		return err
	}
	list, err := d.Readdir(-1)
	d.Close()
	if err != nil {
		return err
	}
	if len(list) == 0 {
		return fmt.Errorf("No files found in %s", path)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].ModTime().Unix() > list[j].ModTime().Unix() })
	file := list[0]

	if file.ModTime().Unix() < afterTime {
		log.Printf("Now: %s, after time: %s", time.Now().Format(timefmt), time.Now().Add(time.Second*time.Duration(newerThanSeconds)).Format(timefmt))
		return fmt.Errorf("No new files found in %s. Newest %s", path, file.ModTime().Format(timefmt))
	}

	data, err := ioutil.ReadFile(filepath.Join(path, file.Name()))
	if err != nil {
		return err
	}
	today := filepath.Base(file.Name())
	gcsPath := fmt.Sprintf("backups/%s/db/%s", dbName, today)

	log.Println("Writing to", gcsPath)
	err = gcsUpload(data, bucket, gcsPath)
	if err != nil {
		return err
	}
	gcsLatestPath := fmt.Sprintf("backups/%s/db/LATEST", dbName)
	log.Println("Writing LATEST to", gcsLatestPath)
	return writeToday(today, bucket, gcsLatestPath)
}

func gcsUpload(src []byte, bucket, dest string) error {

	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return err
	}
	bkt := client.Bucket(bucket)
	obj := bkt.Object(dest)
	w := obj.NewWriter(ctx)
	log.Println("Pushing", len(src), "bytes to bucket", bucket, "at", dest)
	_, err = w.Write(src)
	if err != nil {
		return err
	}
	err = w.Close()
	if err != nil {
		return err
	}
	objAttrs, err := obj.Attrs(ctx)
	log.Printf("object %s has size %d and can be read using %s",
		objAttrs.Name, objAttrs.Size, objAttrs.MediaLink)
	return nil
}

func gzipFile(in []byte) ([]byte, error) {
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	if _, err := gz.Write(in); err != nil {
		return nil, err
	}
	if err := gz.Close(); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func getToday() string {
	return time.Now().Format("2006-01-02-15:04:05")
}

func writeToday(today, bucket, path string) error {
	return gcsUpload([]byte(today), bucket, path)
}

func backupUploads(env, bucket string) error {
	today := getToday()
	gcsPath := fmt.Sprintf("backups/%s/uploads/%s.tgz", env, today)
	tar, err := compress("/uploads")
	if err != nil {
		return err
	}
	gcsUpload(tar, bucket, gcsPath)
	gcsLatestPath := fmt.Sprintf("backups/%s/uploads/LATEST", env)
	writeToday(today, bucket, gcsLatestPath)
	return nil
}
