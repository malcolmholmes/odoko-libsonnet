package main

import (
	"log"
	"os"
	"strconv"
	"strings"
)

func contains(s []string, e string) bool {
	for _, a := range s {
		if a == e {
			return true
		}
	}
	return false
}

func main() {

	log.Println("ODOKO Backup Utility")
	log.Println("====================")

	cmds := strings.Split(os.Getenv("CMD"), ",")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	dbUser := os.Getenv("DB_USER")
	dbPass := os.Getenv("DB_PASS")
	bucket := os.Getenv("BUCKET")
	backupPath := os.Getenv("BACKUP_PATH")
	newerThanSeconds, err := strconv.Atoi(os.Getenv("NEWER_THAN_SECONDS"))
	if err != nil {
		newerThanSeconds = 0
	}

	log.Println("Executing commands", cmds)

	if contains(cmds, "initialise") {
		log.Println("Initialising database")
		dbRootPass := os.Getenv("DB_ROOT_PASS")
		err := initialiseDatabase(dbHost, dbRootPass, dbName, dbUser, dbPass)
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "backup-db") {
		log.Println("Backing up db")
		err := backupMysql(dbHost, dbName, dbUser, dbPass, bucket)
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "backup-file") {
		log.Println("Backing up file")
		err := backupFile(dbName, backupPath, bucket, newerThanSeconds)
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "backup-uploads") {
		log.Println("Backing up uploads")
		err := backupUploads(dbName, bucket)
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "prune-db") {
		log.Println("Pruning old db backups")
		err := pruneBackups(bucket, dbName, "db")
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "prune-uploads") {
		log.Println("Pruning old upload backups")
		err := pruneBackups(bucket, dbName, "uploads")
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "restore-db") {
		log.Println("Restoring db")
		fromEnv := os.Getenv("FROM_ENV")
		domain := os.Getenv("DOMAIN")
		replaceDomains := strings.Split(os.Getenv("REPLACE"), ",")
		err := restoreMysql(fromEnv, dbHost, dbName, dbUser, dbPass, bucket, domain, replaceDomains)
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "restore-uploads") {
		log.Println("Restoring uploads")
		fromEnv := os.Getenv("FROM_ENV")
		err := restoreUploads(fromEnv, dbName, bucket)
		if err != nil {
			panic(err)
		}
	}

	log.Println("Done")
}
