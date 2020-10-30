package main

import (
	"log"
	"os"
	"strings"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	ingressCount = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "dyndns_ingress_count",
		Help: "The number ingresses found",
	})
	domainsChecked = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dyndns_domains_checked_total",
			Help: "The total number of domains checked",
		},
		[]string{"domain"},
	)
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

	cmds := strings.Split(os.Getenv("CMD"), ",")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	dbUser := os.Getenv("DB_USER")
	dbPass := os.Getenv("DB_PASS")
	bucket := os.Getenv("BUCKET")

	log.Println("Executing commands", cmds)
	if contains(cmds, "backup-db") {
		log.Println("Backing up db")
		err := backupMysql(dbHost, dbName, dbUser, dbPass, bucket)
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
		err := pruneBackups(dbName, "db")
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "prune-uploads") {
		log.Println("Pruning old upload backups")
		err := pruneBackups(dbName, "uploads")
		if err != nil {
			panic(err)
		}
	}

	if contains(cmds, "restore-db") {
		log.Println("Backing up uploads")
		fromEnv := os.Getenv("FROM_ENV")
		domain := os.Getenv("DOMAIN")
		replaceDomains := strings.Split(os.Getenv("REPLACE"), ",")
		err := restoreMysql(fromEnv, dbHost, dbName, dbUser, dbPass, bucket, domain, replaceDomains)
		if err != nil {
			panic(err)
		}

	}

	if contains(cmds, "restore-uploads") {
		log.Println("Backing up uploads")
		fromEnv := os.Getenv("FROM_ENV")
		err := restoreUploads(fromEnv, dbName, bucket)
		if err != nil {
			panic(err)
		}
	}
	log.Println("Done")
}
