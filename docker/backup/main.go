package main

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/robfig/cron"
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
	domain := os.Getenv("DOMAIN")
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
		err := backupMysql(domain, dbHost, dbName, dbUser, dbPass, bucket)
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

	if contains(cmds, "backup-loop") {

		if strings.HasPrefix(domain, "dev.") {
			log.Println("Skipping - don't run on dev instances")

		} else {

			schedule := os.Getenv("SCHEDULE")
			c := cron.New()
			c.AddFunc(schedule, func() {
				log.Println("Backing up db")
				err := backupMysql(domain, dbHost, dbName, dbUser, dbPass, bucket)
				if err != nil {
					log.Println(err)
					return
				}
				log.Println("Backing up uploads")
				err = backupUploads(dbName, bucket)
				if err != nil {
					log.Println(err)
					return
				}
				log.Println("Pruning old db backups")
				err = pruneBackups(bucket, dbName, "db")
				if err != nil {
					panic(err)
				}
				log.Println("Pruning old upload backups")
				err = pruneBackups(bucket, dbName, "uploads")
				if err != nil {
					panic(err)
				}
				log.Println("Complete.")
			})
			c.Start()
		}
		for {
			time.Sleep(1000 * time.Second)
		}
	}

	if contains(cmds, "init-and-restore") {
		log.Println("Initialise and restore database")
		writeLog("initialise and restore")
		dbRootPass := os.Getenv("DB_ROOT_PASS")
		dbExists, err := ifDatabaseExists(dbHost, dbRootPass, dbName, dbUser)
		if err != nil {
			panic(err)
		}
		if dbExists {
			writeLog("DB exists")
			log.Println("Database exists. Nothing to do.")
		} else {
			writeLog("INIT DB")
			err := initialiseDatabase(dbHost, dbRootPass, dbName, dbUser, dbPass)
			if err != nil {
				writeLog(fmt.Sprintf("init db error: %s", err))
				panic(err)
			}
			log.Println("Restoring db")
			writeLog("RESTORING DB")
			fromEnv := os.Getenv("FROM_ENV")
			domain := os.Getenv("DOMAIN")
			replaceDomains := strings.Split(os.Getenv("REPLACE"), ",")
			err = restoreMysql(fromEnv, dbHost, dbName, dbUser, dbPass, bucket, domain, replaceDomains)
			if err != nil {
				writeLog(fmt.Sprintf("restore mysql error: %s", err))
				log.Println("Sleeping because of ", err)
				time.Sleep(1000)
				panic(err)
			}

			writeLog("RESTORING UPLOADS")
			log.Println("Restoring uploads")
			err = restoreUploads(fromEnv, dbName, bucket)
			if err != nil {
				writeLog(fmt.Sprintf("restore uploads error: %s", err))
				log.Println("Sleeping because of ", err)
				time.Sleep(1000)
				panic(err)
			}
			writeLog("Done")
		}
	}

	log.Println("Done")
}

func writeLog(msg string) error {
	f, err := os.OpenFile("/var/www/html/wp-content/backup.log",
		os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	t := time.Now().Format("20060102150405")
	podIP := os.Getenv("POD_IP")
	defer f.Close()
	if _, err := f.WriteString(fmt.Sprintf("%s %s %s\n", t, podIP, msg)); err != nil {
		return err
	}
	return nil
}
